# Leaderboard — Dashboard N+1 Katliamı

> Son güncelleme: 2026-04-10 21:26 UTC
> Ölçüm: GitHub Actions `ubuntu-latest` · 3 çalıştırmanın medyanı
> Her öğrencinin **en iyi** skoru gösterilir

| Rank | Öğrenci | Queries | Süre (ms) | Skor (/90) | PR | Tarih |
|------|---------|---------|-----------|------------|-----|-------|
| 🥇 | @dependabot[bot] | 1199 | 658.7 | **5.39** | #21 | 2026-04-10 |

---

## Puanlama

| Bileşen | Ağırlık | Açıklama |
|---------|---------|----------|
| Query azaltma | %60 | Deterministik — her makinede aynı |
| Süre azaltma | %30 | CI runner'da standardize (ubuntu-latest) |
| Stability bonus | — | CI'da uygulanmaz (`rails dojo:run`'da aktif) |

Baseline öğrencinin **kendi kodu** ile ölçülmez — ana repo'nun orijinal
N+1 implementasyonu ile ölçülür. Tüm öğrenciler aynı baseline üzerinden yarışır.
