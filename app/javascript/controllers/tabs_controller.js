import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  
  connect() {
    // Show first tab and panel by default
    if (this.tabTargets.length > 0) {
      this.showTab(this.tabTargets[0])
    }
  }
  
  show(event) {
    event.preventDefault()
    this.showTab(event.currentTarget)
  }
  
  showTab(selectedTab) {
    const panelId = selectedTab.dataset.panel
    
    // Update tab styles
    this.tabTargets.forEach(tab => {
      if (tab === selectedTab) {
        tab.classList.remove("border-transparent", "text-gray-500", "hover:text-gray-700", "hover:border-gray-300")
        tab.classList.add("border-indigo-500", "text-indigo-600")
      } else {
        tab.classList.remove("border-indigo-500", "text-indigo-600")
        tab.classList.add("border-transparent", "text-gray-500", "hover:text-gray-700", "hover:border-gray-300")
      }
    })
    
    // Show/hide panels
    this.panelTargets.forEach(panel => {
      if (panel.id === panelId) {
        panel.classList.remove("hidden")
      } else {
        panel.classList.add("hidden")
      }
    })
  }
}