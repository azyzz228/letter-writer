import {describe, expect, it} from "vitest"
import {generatePassphrase, passwordScore} from "../js/letter_security"

describe("passwordScore", () => {
  it("keeps short passwords weak", () => {
    expect(passwordScore("short")).toBe(0)
  })

  it("rewards length, mixed case, and symbols", () => {
    expect(passwordScore("A-very-long-promise-42")).toBe(4)
  })
})

describe("generatePassphrase", () => {
  it("creates a five-word memorable passphrase from secure values", () => {
    let value = 0
    const result = generatePassphrase(() => new Uint32Array([value++]))

    expect(result.split("-")).toHaveLength(5)
    expect(result).toBe("amber-beloved-candle-distant-evening")
  })
})
