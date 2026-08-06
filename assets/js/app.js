// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/letter_writer"
import topbar from "../vendor/topbar"
import {Editor} from "@tiptap/core"
import StarterKit from "@tiptap/starter-kit"
import CharacterCount from "@tiptap/extension-character-count"
import TextAlign from "@tiptap/extension-text-align"
import Color from "@tiptap/extension-color"
import {TextStyle} from "@tiptap/extension-text-style"

const draftKey = "sealed:letter-draft"

const readDraft = () => {
  try {
    return JSON.parse(sessionStorage.getItem(draftKey) || "{}")
  } catch (_error) {
    return {}
  }
}

const saveDraft = update => {
  const next = {...readDraft(), ...update}
  sessionStorage.setItem(draftKey, JSON.stringify(next))
}

const LetterEditor = {
  mounted() {
    const hiddenInput = this.el.querySelector("[data-editor-json]")
    const surface = this.el.querySelector("[data-editor-surface]")
    const counter = this.el.querySelector("[data-character-count]")
    const draft = readDraft()
    let content = hiddenInput.value || draft.bodyJson

    try {
      content = content ? JSON.parse(content) : "<p>My dearest,</p><p></p>"
    } catch (_error) {
      content = "<p>My dearest,</p><p></p>"
    }

    this.editor = new Editor({
      element: surface,
      content,
      injectCSS: false,
      extensions: [
        StarterKit.configure({
          code: false,
          codeBlock: false,
          heading: {levels: [1, 2, 3]},
          link: {openOnClick: false, autolink: true, defaultProtocol: "https"},
        }),
        TextStyle,
        Color.configure({types: ["textStyle"]}),
        TextAlign.configure({types: ["heading", "paragraph"], alignments: ["left", "center", "right", "justify"]}),
        CharacterCount.configure({limit: 20000}),
      ],
      editorProps: {
        attributes: {
          class: "letter-prose",
          "aria-label": "Letter body",
        },
      },
      onCreate: ({editor}) => this.syncEditor(editor, hiddenInput, counter),
      onUpdate: ({editor}) => this.syncEditor(editor, hiddenInput, counter),
      onSelectionUpdate: ({editor}) => this.updateToolbar(editor),
      onTransaction: ({editor}) => this.updateToolbar(editor),
    })

    this.el.querySelectorAll("[data-command]").forEach(button => {
      button.addEventListener("click", () => this.runCommand(button.dataset.command))
    })

    this.el.querySelectorAll("[data-color]").forEach(button => {
      button.addEventListener("click", () => this.editor.chain().focus().setColor(button.dataset.color).run())
    })
  },

  syncEditor(editor, hiddenInput, counter) {
    const bodyJson = JSON.stringify(editor.getJSON())
    hiddenInput.value = bodyJson
    counter.textContent = `${editor.storage.characterCount.characters().toLocaleString()} / 20,000`
    saveDraft({bodyJson})
  },

  runCommand(command) {
    const chain = this.editor.chain().focus()
    const commands = {
      undo: () => chain.undo().run(),
      redo: () => chain.redo().run(),
      bold: () => chain.toggleBold().run(),
      italic: () => chain.toggleItalic().run(),
      underline: () => chain.toggleUnderline().run(),
      blockquote: () => chain.toggleBlockquote().run(),
      bulletList: () => chain.toggleBulletList().run(),
      orderedList: () => chain.toggleOrderedList().run(),
      "heading-1": () => chain.toggleHeading({level: 1}).run(),
      "heading-2": () => chain.toggleHeading({level: 2}).run(),
      "align-left": () => chain.setTextAlign("left").run(),
      "align-center": () => chain.setTextAlign("center").run(),
      "align-right": () => chain.setTextAlign("right").run(),
      link: () => {
        const current = this.editor.getAttributes("link").href || ""
        const href = window.prompt("Paste a web or email address", current)
        if (href === null) return
        if (href.trim() === "") return chain.unsetLink().run()
        return chain.extendMarkRange("link").setLink({href: href.trim()}).run()
      },
    }

    commands[command]?.()
  },

  updateToolbar(editor) {
    const active = {
      bold: editor.isActive("bold"),
      italic: editor.isActive("italic"),
      underline: editor.isActive("underline"),
      blockquote: editor.isActive("blockquote"),
      bulletList: editor.isActive("bulletList"),
      orderedList: editor.isActive("orderedList"),
      "heading-1": editor.isActive("heading", {level: 1}),
      "heading-2": editor.isActive("heading", {level: 2}),
      "align-left": editor.isActive({textAlign: "left"}),
      "align-center": editor.isActive({textAlign: "center"}),
      "align-right": editor.isActive({textAlign: "right"}),
      link: editor.isActive("link"),
    }

    this.el.querySelectorAll("[data-command]").forEach(button => {
      button.classList.toggle("is-active", Boolean(active[button.dataset.command]))
    })
  },

  destroyed() {
    this.editor?.destroy()
  },
}

const SealForm = {
  mounted() {
    const draft = readDraft()
    const restorable = ["to_name", "from_name", "title"]

    restorable.forEach(field => {
      const input = this.el.querySelector(`[name="seal_form[${field}]"]`)
      if (input && !input.value && draft[field]) input.value = draft[field]
    })

    this.el.addEventListener("input", event => {
      const match = event.target.name?.match(/^seal_form\[(to_name|from_name|title)\]$/)
      if (match) saveDraft({[match[1]]: event.target.value})
      if (event.target.name === "seal_form[password]") this.updateStrength(event.target.value)
    })

    this.el.querySelector("[data-generate-passphrase]")?.addEventListener("click", () => {
      const words = ["amber", "beloved", "candle", "distant", "evening", "forever", "garden", "harbor", "lilac", "moon", "paper", "promise", "quiet", "ribbon", "starlight", "together"]
      const chosen = Array.from({length: 5}, () => words[crypto.getRandomValues(new Uint32Array(1))[0] % words.length])
      const passphrase = chosen.join("-")
      const password = this.el.querySelector('[name="seal_form[password]"]')
      const confirmation = this.el.querySelector('[name="seal_form[password_confirmation]"]')
      password.value = passphrase
      confirmation.value = passphrase
      password.dispatchEvent(new Event("input", {bubbles: true}))
      confirmation.dispatchEvent(new Event("input", {bubbles: true}))
    })

    this.handleEvent("letter-sealed", () => sessionStorage.removeItem(draftKey))
  },

  updateStrength(password) {
    const bar = this.el.querySelector("[data-password-strength]")
    if (!bar) return
    let score = 0
    if (password.length >= 8) score++
    if (password.length >= 14) score++
    if (/[A-Z]/.test(password) && /[a-z]/.test(password)) score++
    if (/\d|[^\w\s]/.test(password)) score++
    bar.style.width = `${score * 25}%`
    bar.dataset.score = score
  },
}

const CopyLinks = {
  mounted() {
    this.el.querySelectorAll("[data-copy]").forEach(button => {
      button.addEventListener("click", async () => {
        const value = this.el.querySelector(button.dataset.copy)?.textContent.trim()
        if (!value) return
        await navigator.clipboard.writeText(value)
        const original = button.innerHTML
        button.textContent = "Copied"
        window.setTimeout(() => button.innerHTML = original, 1600)
      })
    })
  },
}

const ReaderPreferences = {
  mounted() {
    const button = this.el.querySelector("[data-easy-read]")
    const setPreference = enabled => {
      this.el.classList.toggle("easy-read", enabled)
      button.setAttribute("aria-pressed", String(enabled))
      localStorage.setItem("sealed:easy-read", String(enabled))
    }
    setPreference(localStorage.getItem("sealed:easy-read") === "true")
    button.addEventListener("click", () => setPreference(!this.el.classList.contains("easy-read")))
  },
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, LetterEditor, SealForm, CopyLinks, ReaderPreferences},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
