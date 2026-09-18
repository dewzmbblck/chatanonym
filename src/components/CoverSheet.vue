<script setup>
import { ref } from 'vue'

const props = defineProps({
  loading: { type: Boolean, default: false },
  errorMessage: { type: String, default: '' },
})
const emit = defineEmits(['submit'])

const codename = ref('')

function onSubmit() {
  const trimmed = codename.value.trim()
  if (trimmed.length < 2 || trimmed.length > 24) return
  emit('submit', trimmed)
}
</script>

<template>
  <div class="cover">
    <div class="cover__sheet">
      <p class="cover__tag">MASUK SALURAN · ANONYM</p>
      <h1 class="cover__title">Masukkan nama samaran Anda</h1>
      <p class="cover__body">
        Tidak ada nama asli, tidak ada nomor telepon. Nama ini adalah satu-satunya
        identitas Anda di saluran ini. Orang lain hanya akan mengenal Anda
        lewat nama ini.
      </p>

      <form class="cover__form" @submit.prevent="onSubmit">
        <label class="cover__label" for="codename">NAMA SAMARAN</label>
        <input
          id="codename"
          v-model="codename"
          class="cover__input"
          type="text"
          maxlength="24"
          autocomplete="off"
          placeholder="mis. Anak Ayam"
          :disabled="loading"
        />
        <button class="cover__button" type="submit" :disabled="loading || codename.trim().length < 2">
          {{ loading ? 'Membuka saluran…' : 'Masuk' }}
        </button>
        <p v-if="errorMessage" class="cover__error">{{ errorMessage }}</p>
      </form>
    </div>
  </div>
</template>

<style scoped>
.cover {
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
  background:
    linear-gradient(var(--hairline) 1px, transparent 1px) 0 0 / 100% 42px,
    var(--bg);
}

.cover__sheet {
  width: 100%;
  max-width: 440px;
  background: var(--surface);
  border: 1px solid var(--hairline);
  padding: 40px 36px;
}

.cover__tag {
  font-family: var(--font-mono);
  font-size: 11px;
  letter-spacing: 0.06em;
  color: var(--accent);
  margin: 0 0 18px;
}

.cover__title {
  font-family: var(--font-serif);
  font-weight: 600;
  font-size: 28px;
  line-height: 1.25;
  margin: 0 0 14px;
  color: var(--text);
}

.cover__body {
  font-size: 14.5px;
  line-height: 1.6;
  color: var(--text-muted);
  margin: 0 0 28px;
  max-width: 38ch;
}

.cover__form {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.cover__label {
  font-family: var(--font-mono);
  font-size: 11px;
  color: var(--text-faint);
}

.cover__input {
  background: var(--bg);
  border: 1px solid var(--hairline);
  color: var(--text);
  padding: 12px 14px;
  font-size: 15px;
  margin-bottom: 6px;
}

/* .cover__input:focus-visible {
  border-color: var(--accent);
} */

.cover__button {
  background: var(--accent);
  color: var(--accent-ink);
  border: none;
  font-weight: 600;
  font-size: 14.5px;
  padding: 12px 16px;
  transition: opacity 0.15s ease;
}

.cover__button:disabled {
  opacity: 0.45;
  cursor: not-allowed;
}

.cover__button:not(:disabled):hover {
  opacity: 0.88;
}

.cover__error {
  color: var(--danger);
  font-size: 13px;
  margin: 6px 0 0;
}
</style>
