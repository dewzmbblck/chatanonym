<script setup>
import { computed, nextTick, onMounted, ref, watch } from 'vue'

const props = defineProps({
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
  isPrivate: { type: Boolean, default: false },
  myId: { type: String, required: true },
  messages: { type: Array, required: true }, // [{id, sender_id, sender_name, content, created_at}]
})
const emit = defineEmits(['send'])

const draft = ref('')
const scrollEl = ref(null)

// true jika posisi scroll sudah di (dekat) paling bawah
const atBottom = ref(true)
// jumlah pesan baru dari orang lain yang masuk saat pengguna sedang membaca pesan lama
const unread = ref(0)

// jarak (px) dari dasar yang masih dianggap "di bawah"
const BOTTOM_THRESHOLD = 80

const lastMessage = computed(() => props.messages[props.messages.length - 1] ?? null)

function scrollToBottom(smooth = true) {
  nextTick(() => {
    const el = scrollEl.value
    if (!el) return
    el.scrollTo({ top: el.scrollHeight, behavior: smooth ? 'smooth' : 'auto' })
    unread.value = 0
  })
}

function onScroll() {
  const el = scrollEl.value
  if (!el) return
  atBottom.value = el.scrollHeight - el.scrollTop - el.clientHeight < BOTTOM_THRESHOLD
  if (atBottom.value) unread.value = 0
}

watch(
  () => [props.title, lastMessage.value?.id],
  ([title], [oldTitle]) => {
    // Pindah saluran: langsung ke bawah tanpa animasi
    if (title !== oldTitle) {
      atBottom.value = true
      scrollToBottom(false)
      return
    }

    const last = lastMessage.value
    if (!last) return

    // Pesan sendiri, atau pengguna memang sedang di bawah: ikut turun
    if (last.sender_id === props.myId || atBottom.value) {
      scrollToBottom(true)
    } else {
      // Sedang membaca pesan lama: jangan ditarik ke bawah, tampilkan penanda
      unread.value++
    }
  },
)

onMounted(() => scrollToBottom(false))

function onSend() {
  const text = draft.value.trim()
  if (!text) return
  emit('send', text)
  draft.value = ''
}

function formatTime(iso) {
  const d = new Date(iso)
  return d.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })
}
</script>

<template>
  <section class="panel">
    <header class="panel__header">
      <div>
        <p class="panel__eyebrow">{{ isPrivate ? 'SALURAN PRIBADI' : 'SALURAN TERBUKA' }}</p>
        <h2 class="panel__title">{{ title }}</h2>
      </div>
      <p v-if="subtitle" class="panel__subtitle">{{ subtitle }}</p>
    </header>

    <div class="panel__body">
      <div ref="scrollEl" class="panel__scroll" @scroll.passive="onScroll">
        <p v-if="messages.length === 0" class="panel__empty">
          Belum ada pesan.
        </p>

        <div
          v-for="m in messages"
          :key="m.id"
          class="msg"
          :class="m.sender_id === myId ? 'msg--mine' : 'msg--other'"
        >
          <p class="msg__meta">
            <span class="msg__name">{{ m.sender_id === myId ? 'Anda' : m.sender_name }}</span>
            <span class="msg__time">{{ formatTime(m.created_at) }}</span>
          </p>
          <p class="msg__content">{{ m.content }}</p>
        </div>
      </div>

      <button
        v-if="!atBottom"
        class="panel__jump"
        type="button"
        :aria-label="unread ? `${unread} pesan baru, turun ke pesan terbaru` : 'Turun ke pesan terbaru'"
        @click="scrollToBottom(true)"
      >
        <i class="bi bi-arrow-down"></i>
        <span v-if="unread" class="panel__jump-count">{{ unread }} pesan baru</span>
      </button>
    </div>

    <form class="panel__composer" @submit.prevent="onSend">
      <input
        v-model="draft"
        class="panel__input"
        type="text"
        maxlength="1000"
        autocomplete="off"
        :placeholder="isPrivate ? `Kirim pesan pribadi…` : 'Ketik pesan untuk saluran umum…'"
      />
      <button class="panel__send" type="submit" :disabled="!draft.trim()"><i class="bi bi-send"></i></button>
    </form>
  </section>
</template>

<style scoped>
.panel {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-width: 0;
  /* Kunci agar scroll bekerja: panel harus punya tinggi terbatas */
  height: 100%;
  min-height: 0;
  overflow: hidden;
}

.panel__header {
  flex-shrink: 0;
  padding: 18px 28px;
  border-bottom: 1px solid var(--hairline);
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
}

.panel__eyebrow {
  font-family: var(--font-mono);
  font-size: 10.5px;
  letter-spacing: 0.05em;
  color: var(--accent);
  margin: 0 0 4px;
}

.panel__title {
  /* font-family: var(--font-serif); */
  font-size: 19px;
  font-weight: 600;
  margin: 0;
  color: var(--text);
}

.panel__subtitle {
  font-size: 12px;
  color: var(--text-faint);
  font-family: var(--font-sans);
}

/* Pembungkus area scroll, tempat tombol "turun" diposisikan */
.panel__body {
  position: relative;
  flex: 1 1 0;
  min-height: 0; /* wajib: tanpa ini flex child tidak mau menyusut sehingga tidak bisa di-scroll */
  display: flex;
  flex-direction: column;
}

.panel__scroll {
  flex: 1 1 0;
  min-height: 0;
  overflow-y: auto;
  overscroll-behavior: contain; /* scroll di chat tidak ikut menggulung halaman */
  padding: 24px 28px;
  display: flex;
  flex-direction: column;
  gap: 16px;
  scrollbar-width: thin;
  scrollbar-color: var(--hairline) transparent;
}

.panel__scroll::-webkit-scrollbar {
  width: 8px;
}

.panel__scroll::-webkit-scrollbar-track {
  background: transparent;
}

.panel__scroll::-webkit-scrollbar-thumb {
  background: var(--hairline);
  border-radius: 4px;
}

.panel__scroll::-webkit-scrollbar-thumb:hover {
  background: var(--text-faint);
}

.panel__empty {
  color: var(--text-faint);
  font-size: 13.5px;
  margin: auto;
}

.msg {
  flex-shrink: 0; /* pesan tidak boleh tergencet saat daftar panjang */
  max-width: 60ch;
  padding: 10px 14px;
  border-left: 2px solid var(--other-dim);
}

.msg--mine {
  border-left-color: var(--accent-dim);
  align-self: flex-end;
}

.msg__meta {
  display: flex;
  gap: 10px;
  margin: 0 0 4px;
  font-family: var(--font-mono);
  font-size: 10.5px;
}

.msg__name {
  color: var(--other);
}

.msg--mine .msg__name {
  color: var(--accent);
}

.msg__time {
  color: var(--text-faint);
}

.msg__content {
  margin: 0;
  font-size: 14.5px;
  line-height: 1.55;
  color: var(--text);
  white-space: pre-wrap;
  word-break: break-word;
}

/* Tombol turun ke pesan terbaru */
.panel__jump {
  position: absolute;
  right: 28px;
  bottom: 16px;
  display: inline-flex;
  align-items: center;
  gap: 8px;
  min-width: 40px;
  height: 40px;
  padding: 0 12px;
  justify-content: center;
  background: var(--accent);
  color: var(--text);
  border: none;
  border-radius: 20px;
  font-size: 13px;
  cursor: pointer;
}

.panel__jump:focus-visible,
.panel__send:focus-visible {
  outline: 2px solid var(--text);
  outline-offset: 2px;
}

.panel__composer {
  flex-shrink: 0;
  display: flex;
  gap: 10px;
  padding: 16px 28px;
  border-top: 1px solid var(--hairline);
}

.panel__input {
  flex: 1;
  background: var(--surface);
  border: 1px solid var(--hairline);
  border-radius: 18px;
  color: var(--text);
  padding: 11px 14px;
  font-size: 14.5px;
}

/* .panel__input:focus-visible {
  border-color: var(--accent);
} */

.panel__send {
  background: var(--accent);
  color: var(--text);
  border: none;
  border-radius: 50%; /* Membuat tombol jadi lingkaran sempurna */
  width: 44px;       /* Lebar dan tinggi harus sama */
  height: 44px;
  display: inline-flex;
  align-items: center;
  justify-content: center; /* Membuat ikon pas di tengah-tengah */
  font-size: 18px;   /* Ukuran ikon yang proporsional dengan kotak */
  cursor: pointer;
}

.panel__send:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

@media (prefers-reduced-motion: reduce) {
  .panel__scroll {
    scroll-behavior: auto;
  }
}

@media (max-width: 720px) {
  .panel__header,
  .panel__scroll,
  .panel__composer {
    padding-left: 16px;
    padding-right: 16px;
  }

  .panel__jump {
    right: 16px;
  }
}
</style>