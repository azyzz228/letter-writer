export const passphraseWords = [
  "amber", "beloved", "candle", "distant", "evening", "forever", "garden", "harbor",
  "lilac", "moon", "paper", "promise", "quiet", "ribbon", "starlight", "together",
]

export const passwordScore = password => {
  let score = 0
  if (password.length >= 8) score++
  if (password.length >= 14) score++
  if (/[A-Z]/.test(password) && /[a-z]/.test(password)) score++
  if (/\d|[^\w\s]/.test(password)) score++
  return score
}

export const generatePassphrase = randomValues => {
  return Array.from({length: 5}, () => {
    const random = randomValues()[0]
    return passphraseWords[random % passphraseWords.length]
  }).join("-")
}
