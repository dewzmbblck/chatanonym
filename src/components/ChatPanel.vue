<script setup>
import { nextTick, ref, watch } from 'vue'

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

function scrollToBottom() {
  nextTick(() => {
    if (scrollEl.value) scrollEl.value.scrollTop = scrollEl.value.scrollHeight
  })
}

watch(() => props.messages.length, scrollToBottom)
watch(() => props.title, scrollToBottom)

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

    <div ref="scrollEl" class="panel__scroll">
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
}

.panel__header {
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

.panel__scroll {
  flex: 1;
  overflow-y: auto;
  padding: 24px 28px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.panel__empty {
  color: var(--text-faint);
  font-size: 13.5px;
  margin: auto;
}

.msg {
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

.panel__composer {
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

@media (max-width: 720px) {
  .panel__header,
  .panel__scroll,
  .panel__composer {
    padding-left: 16px;
    padding-right: 16px;
  }
}
</style>
