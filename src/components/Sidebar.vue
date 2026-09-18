<script setup>
import { ref } from 'vue'

const props = defineProps({
  myId: { type: String, required: true },
  myNickname: { type: String, required: true },
  contacts: { type: Array, required: true }, // [{id, nickname}] — thread yang sudah pernah Anda buka
  activeThread: { type: String, default: 'public' }, // 'public' | user id
  unread: { type: Object, default: () => ({}) },
  openIdError: { type: String, default: '' },
  openingId: { type: Boolean, default: false },
})
const emit = defineEmits(['select', 'open-by-id'])

const idInput = ref('')
const copied = ref(false)

function submitId() {
  const value = idInput.value.trim()
  if (!value) return
  emit('open-by-id', value)
  idInput.value = ''
}

async function copyMyId() {
  try {
    await navigator.clipboard.writeText(props.myId)
    copied.value = true
    setTimeout(() => (copied.value = false), 1500)
  } catch {
    // clipboard API tidak tersedia (mis. http non-secure) — biarkan pengguna menyalin manual
  }
}
</script>

<template>
  <aside class="sidebar">
    <div class="sidebar__me">
      <span class="sidebar__me-dot" aria-hidden="true"><i class="bi bi-bug-fill"></i></span>
       
      <div class="sidebar__me-text">
        <p class="sidebar__me-label">ANDA TERVERIFIKASI SEBAGAI</p>
        <p class="sidebar__me-name">{{ myNickname }}</p>
      </div>
    </div>

    <!-- <div class="sidebar__myid">
      <p class="sidebar__myid-label">ID ANDA</p>
      <div class="sidebar__myid-row">
        <code class="sidebar__myid-value">{{ myId }}</code>
        <button type="button" class="sidebar__copy" @click="copyMyId">
          {{ copied ? 'Tersalin' : 'Salin' }}
        </button>
      </div>
    </div> -->

    <form class="sidebar__openform" @submit.prevent="submitId">
      <label class="sidebar__myid-label" for="target-id">BUKA OBROLAN PRIBADI MENGGUNAKAN ID</label>
      <div class="sidebar__openform-row">
        <input
          id="target-id"
          v-model="idInput"
          class="sidebar__openform-input"
          type="text"
          autocomplete="off"
          placeholder="Masukkan ID tujuan…"
        />
        <button type="submit" class="sidebar__copy" :disabled="!idInput.trim() || openingId">
          {{ openingId ? 'Mencari…' : 'Buka' }}
        </button>
      </div>
      <p v-if="openIdError" class="sidebar__openform-error">{{ openIdError }}</p>
    </form>

    <button
      class="sidebar__item"
      :class="{ 'sidebar__item--active': activeThread === 'public' }"
      @click="emit('select', 'public')"
    >
      <span class="sidebar__item-icon"><i class="bi bi-broadcast-pin"></i></span>
      <span class="sidebar__item-name">Saluran Umum</span>
    </button>

    <p class="sidebar__section">PERCAKAPAN PRIBADI</p>

    <div class="sidebar__list">
      <button
        v-for="c in contacts"
        :key="c.id"
        class="sidebar__item"
        :class="{ 'sidebar__item--active': activeThread === c.id }"
        @click="emit('select', c.id)"
      >
        <span class="sidebar__item-icon sidebar__item-icon--user">●</span>
        <span class="sidebar__item-name">{{ c.nickname }}</span>
        <span v-if="unread[c.id]" class="sidebar__badge">{{ unread[c.id] }}</span>
      </button>

      <p v-if="contacts.length === 0" class="sidebar__empty">
        Belum ada percakapan pribadi. Tempelkan ID seseorang di atas untuk memulai.
      </p>
    </div>
  </aside>
</template>

<style scoped>
.sidebar {
  width: 280px;
  min-width: 280px;
  background: var(--surface);
  border-right: 1px solid var(--hairline);
  display: flex;
  flex-direction: column;
  padding: 20px 0;
  overflow-y: auto;
}

.sidebar__me {
  display: flex;
  align-items: center;
  gap: 15px;
  padding: 0 20px 16px;
  margin-bottom: 4px;
}

.sidebar__me-dot {
  /* width: 8px;
  height: 8px;
  text-align: center;
  border-radius: 50%;
  background: var(--accent);
  flex-shrink: 0; */
  font-size: large;
}

.sidebar__me-label {
  font-family: var(--font-mono);
  font-size: 10px;
  color: var(--text-faint);
  margin: 0 0 2px;
  letter-spacing: 0.04em;
}

.sidebar__me-name {
  font-family: var(--font-serif);
  font-size: 15px;
  color: var(--text);
  margin: 0;
}

.sidebar__myid {
  margin: 0 20px 16px;
  padding: 12px;
  background: var(--bg);
  border: 1px solid var(--hairline);
}

.sidebar__myid-label {
  font-family: var(--font-mono);
  font-size: 10px;
  color: var(--text-faint);
  letter-spacing: 0.02em;
  margin: 0 0 18px;
  line-height: 1.5;
}

.sidebar__myid-row {
  display: flex;
  gap: 8px;
  align-items: center;
}

.sidebar__myid-value {
  flex: 1;
  font-family: var(--font-mono);
  font-size: 11px;
  color: var(--text);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.sidebar__copy {
  flex-shrink: 0;
  background: var(--surface-raised);
  border: 1px solid var(--hairline);
  border-radius: 9px;
  color: var(--text);
  font-size: 11.5px;
  padding: 6px 10px;
  font-family: var(--font-mono);
}

.sidebar__copy:hover {
  border-color: var(--accent);
}

.sidebar__copy:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.sidebar__openform {
  margin: 0 20px 18px;
  padding-bottom: 16px;
  border-bottom: 1px solid var(--hairline);
}

.sidebar__openform-row {
  display: flex;
  gap: 8px;
  margin-top: 8px;
}

.sidebar__openform-input {
  flex: 1;
  min-width: 0;
  background: var(--bg);
  border: 1px solid var(--hairline);
  border-radius: 9px;
  color: var(--text);
  padding: 8px 10px;
  font-size: 12.5px;
  font-family: var(--font-mono);
}

/* .sidebar__openform-input:focus-visible {
  border-color: var(--accent);
} */

.sidebar__openform-error {
  color: var(--danger);
  font-size: 12px;
  margin: 8px 0 0;
}

.sidebar__section {
  font-family: var(--font-mono);
  font-size: 10.5px;
  color: var(--text-faint);
  letter-spacing: 0.04em;
  margin: 15px 20px 8px;
}

.sidebar__list {
  flex: 1;
}

.sidebar__item {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 10px;
  background: transparent;
  border: none;
  border-left: 2px solid transparent;
  color: var(--text-muted);
  padding: 10px 20px;
  font-size: 14px;
  text-align: left;
}

.sidebar__item:hover {
  background: var(--surface-raised);
  color: var(--text);
}

.sidebar__item--active {
  background: var(--surface-raised);
  border-left-color: var(--accent);
  color: var(--text);
}

.sidebar__item-icon {
  font-size: 12px;
  color: var(--accent);
  width: 14px;
  text-align: center;
}

.sidebar__item-icon--user {
  font-size: 9px;
  color: var(--other);
}

.sidebar__item-name {
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.sidebar__badge {
  background: var(--accent);
  color: var(--accent-ink);
  font-family: var(--font-mono);
  font-size: 10px;
  padding: 1px 6px;
  border-radius: 8px;
}

.sidebar__empty {
  padding: 0 20px;
  font-size: 12.5px;
  color: var(--text-faint);
  line-height: 1.5;
}

@media (max-width: 720px) {
  .sidebar {
    width: 100%;
    min-width: 0;
    max-height: 46vh;
    border-right: none;
    border-bottom: 1px solid var(--hairline);
  }
}
</style>
