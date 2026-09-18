<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref } from 'vue'
import { supabase } from './supabase'
import CoverSheet from './components/CoverSheet.vue'
import Sidebar from './components/Sidebar.vue'
import ChatPanel from './components/ChatPanel.vue'

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

const booting = ref(true)
const loadingLogin = ref(false)
const loginError = ref('')

const myId = ref(null)
const myNickname = ref('')
const hasNickname = ref(false)

const activeThread = ref('public') // 'public' | other user's id
const messages = reactive({ public: [] }) // { public: [...], [userId]: [...] }
const unread = reactive({}) // { [userId]: count }
const openIdError = ref('')
const openingId = ref(false)

// Nicknames of people we've actually exchanged messages with, or resolved
// once via the narrow get_nickname_by_id lookup when opening a new thread.
// There is deliberately no directory of everyone's id/nickname — this is
// only ever populated for a specific id the user already typed in.
const knownNicknames = reactive({})

let publicChannel = null
let inboxChannel = null

function nicknameFor(id) {
  const thread = messages[id]
  if (thread) {
    const fromThem = thread.find((m) => m.sender_id === id)
    if (fromThem) return fromThem.sender_name
  }
  return knownNicknames[id] || null
}

// Private threads are only ever the ones this user has explicitly opened
// (by typing an id) or received a message on — never a browsable list of
// other users.
const contacts = computed(() => {
  const ids = Object.keys(messages).filter((k) => k !== 'public')
  return ids
    .map((id) => ({ id, nickname: nicknameFor(id) || `ID …${id.slice(-6)}` }))
    .sort((a, b) => a.nickname.localeCompare(b.nickname))
})

const activeMessages = computed(() => messages[activeThread.value] || [])
const activeTitle = computed(() => {
  if (activeThread.value === 'public') return 'Saluran Umum'
  return `Anda sedang berbicara dengan: ${nicknameFor(activeThread.value)}` || `ID …${activeThread.value.slice(-6)}`
})
const activeSubtitle = computed(() => {
  if (activeThread.value === 'public') return 'Terlihat oleh semua orang yang online'
  return 'Hanya terlihat oleh Anda berdua'
})

function upsertMessage(thread, row) {
  if (!messages[thread]) messages[thread] = []
  if (messages[thread].some((m) => m.id === row.id)) return
  messages[thread].push(row)
}

async function bootstrap() {
  booting.value = true

  const { data: existing } = await supabase.auth.getSession()
  let session = existing.session

  if (!session) {
    const { data, error } = await supabase.auth.signInAnonymously()
    if (error) {
      loginError.value = 'Gagal membuat sesi anonim: ' + error.message
      booting.value = false
      return
    }
    session = data.session
  }

  myId.value = session.user.id

  const { data: profile } = await supabase
    .from('profiles')
    .select('nickname')
    .eq('id', myId.value)
    .maybeSingle()

  if (profile?.nickname) {
    myNickname.value = profile.nickname
    hasNickname.value = true
    await afterLogin()
  }

  booting.value = false
}

async function submitNickname(codename) {
  loadingLogin.value = true
  loginError.value = ''

  const { error } = await supabase
    .from('profiles')
    .upsert({ id: myId.value, nickname: codename, updated_at: new Date().toISOString() })

  if (error) {
    loginError.value = 'Nama samaran gagal disimpan: ' + error.message
    loadingLogin.value = false
    return
  }

  myNickname.value = codename
  hasNickname.value = true
  await afterLogin()
  loadingLogin.value = false
}

async function afterLogin() {
  await loadHistory()
  subscribeRealtime()
}

async function loadHistory() {
  const { data, error } = await supabase
    .from('messages')
    .select('id, sender_id, sender_name, receiver_id, content, created_at')
    .order('created_at', { ascending: true })
    .limit(500)

  if (error || !data) return

  for (const row of data) {
    if (row.receiver_id === null) {
      upsertMessage('public', row)
    } else {
      const otherId = row.sender_id === myId.value ? row.receiver_id : row.sender_id
      upsertMessage(otherId, row)
    }
  }
}

function subscribeRealtime() {
  publicChannel = supabase
    .channel('public-room-changes')
    .on(
      'postgres_changes',
      { event: 'INSERT', schema: 'public', table: 'messages', filter: 'receiver_id=is.null' },
      (payload) => upsertMessage('public', payload.new)
    )
    .subscribe()

  // Only messages addressed to me — this is how a private reply arrives even
  // from someone I've never opened a thread with before; their nickname
  // comes straight off the message row itself, not from any lookup.
  inboxChannel = supabase
    .channel(`private-inbox-${myId.value}`)
    .on(
      'postgres_changes',
      { event: 'INSERT', schema: 'public', table: 'messages', filter: `receiver_id=eq.${myId.value}` },
      (payload) => {
        const row = payload.new
        upsertMessage(row.sender_id, row)
        if (activeThread.value !== row.sender_id) {
          unread[row.sender_id] = (unread[row.sender_id] || 0) + 1
        }
      }
    )
    .subscribe()
}

function selectThread(threadId) {
  activeThread.value = threadId
  if (unread[threadId]) unread[threadId] = 0
}

// The only way to reach someone privately: type/paste their exact id. This
// calls a database function that returns a match for that one id only —
// there is no endpoint anywhere that lists other users.
async function openThreadById(rawId) {
  openIdError.value = ''
  const id = rawId.trim()

  if (id === myId.value) {
    openIdError.value = 'Masukkan ID lain.'
    return
  }
  if (!UUID_RE.test(id)) {
    openIdError.value = 'Format ID tidak valid.'
    return
  }

  if (!messages[id]) {
    openingId.value = true
    const { data, error } = await supabase.rpc('get_nickname_by_id', { target_id: id })
    openingId.value = false

    if (error || !data) {
      openIdError.value = 'ID tidak ditemukan.'
      return
    }
    knownNicknames[id] = data
    messages[id] = []
  }

  selectThread(id)
}

async function sendMessage(content) {
  const isPrivate = activeThread.value !== 'public'
  const row = {
    sender_id: myId.value,
    sender_name: myNickname.value,
    receiver_id: isPrivate ? activeThread.value : null,
    content,
  }

  const { data, error } = await supabase.from('messages').insert(row).select().single()
  if (error) {
    console.error('Gagal mengirim pesan:', error.message)
    return
  }

  // Public messages arrive back via the public-room-changes subscription too;
  // upsertMessage dedupes by id so this optimistic add is safe either way.
  upsertMessage(isPrivate ? activeThread.value : 'public', data)
}

onMounted(bootstrap)

onBeforeUnmount(() => {
  publicChannel?.unsubscribe()
  inboxChannel?.unsubscribe()
})
</script>

<template>
  <div v-if="booting" class="boot">
    <p class="boot__text">Mencari saluran aman…</p>
  </div>

  <CoverSheet
    v-else-if="!hasNickname"
    :loading="loadingLogin"
    :error-message="loginError"
    @submit="submitNickname"
  />

  <div v-else class="app">
    <Sidebar
      :my-id="myId"
      :my-nickname="myNickname"
      :contacts="contacts"
      :active-thread="activeThread"
      :unread="unread"
      :open-id-error="openIdError"
      :opening-id="openingId"
      @select="selectThread"
      @open-by-id="openThreadById"
    />
    <ChatPanel
      :key="activeThread"
      :title="activeTitle"
      :subtitle="activeSubtitle"
      :is-private="activeThread !== 'public'"
      :my-id="myId"
      :messages="activeMessages"
      @send="sendMessage"
    />
  </div>
</template>

<style scoped>
.boot {
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.boot__text {
  font-family: var(--font-mono);
  color: var(--text-faint);
  font-size: 13px;
}

.app {
  height: 100%;
  display: flex;
}

@media (max-width: 720px) {
  .app {
    flex-direction: column;
  }
}
</style>
