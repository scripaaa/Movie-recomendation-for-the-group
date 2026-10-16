module ApplicationHelper
  UI_ICON_PATHS = {
    bell: [ "M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9", "M10 21h4" ],
    star: [ "m12 3 2.8 5.7 6.3.9-4.55 4.45 1.07 6.28L12 17.36l-5.62 2.97 1.07-6.28L2.9 9.6l6.3-.9L12 3Z" ],
    chart: [ "M4 4v16h16", "M9 16v-4M14 16V8M19 16V4" ],
    users: [ "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2", "M13 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0Z", "M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" ],
    film: [ "M4 3h16v18H4V3Z", "M8 3v18M16 3v18M4 8h4M4 16h4M16 8h4M16 16h4M8 12h8" ],
    sparkles: [ "m12 3 2.5 6.5L21 12l-6.5 2.5L12 21l-2.5-6.5L3 12l6.5-2.5L12 3Z", "M4 3v4M2 5h4M20 17v4M18 19h4" ],
    search: [ "M19 11a8 8 0 1 1-16 0 8 8 0 0 1 16 0Z", "m17 17 4 4" ],
    plus: [ "M12 5v14M5 12h14" ],
    close: [ "m6 6 12 12M18 6 6 18" ]
  }.freeze

  def ui_icon(name, classes: "size-5")
    tag.svg(class: classes, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", "stroke-width": 1.75, "stroke-linecap": "round", "stroke-linejoin": "round", aria: { hidden: true }, focusable: false) do
      safe_join(UI_ICON_PATHS.fetch(name).map { |path| tag.path(d: path) })
    end
  end

  def ui_button_classes(variant = :primary)
    base = "inline-flex min-h-11 items-center justify-center gap-2 rounded-xl px-4 py-2.5 text-sm font-semibold transition focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-300 disabled:cursor-not-allowed disabled:opacity-50"
    variants = {
      primary: "bg-brand-600 text-white shadow-sm hover:bg-brand-700 disabled:hover:bg-brand-600",
      secondary: "border border-line bg-surface text-ink-secondary hover:bg-surface-hover disabled:hover:bg-surface"
    }
    class_names(base, variants.fetch(variant))
  end

  def ui_input_classes
    "block min-h-11 w-full rounded-xl border border-line-strong bg-surface-raised px-3.5 py-2.5 text-base text-ink shadow-xs placeholder:text-ink-muted focus:border-brand-300 focus:outline-2 focus:outline-brand-300/40 disabled:cursor-not-allowed disabled:bg-surface disabled:text-ink-muted aria-invalid:border-rose-400 aria-invalid:focus:outline-rose-400/40"
  end

  def ui_label_classes
    "mb-2 block text-sm font-medium text-ink-secondary"
  end
end
