import { Controller } from "@hotwired/stimulus"

// Notification bell. Subscribes to the per-user ActionCable channel
// (if available) and updates the unread count badge in real time.
//
// Drop-in: add `data-controller="notification-bell"` to the bell
// element. Pair with `data-notification-bell-target="count"` on the
// element that shows the unread number.
export default class extends Controller {
  static targets = ["count"]
  static values  = { count: Number }

  connect() {
    if (typeof window.consumer === "undefined") return

    this.subscription = window.consumer.subscriptions.create(
      { channel: "Notifications::NotificationChannel" },
      { received: (data) => this.update(data) }
    )
  }

  disconnect() {
    this.subscription?.unsubscribe()
  }

  update({ unread_count }) {
    if (typeof unread_count !== "number") return
    this.countValue = unread_count
    if (this.hasCountTarget) {
      this.countTarget.textContent = unread_count
      this.countTarget.style.display = unread_count > 0 ? "" : "none"
    }
  }
}
