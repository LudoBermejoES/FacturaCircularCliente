import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="workflow-diagram"
export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    states: Array,
    transitions: Array,
    width: { type: Number, default: 800 },
    height: { type: Number, default: 400 }
  }

  connect() {
    this.drawWorkflow()
  }

  statesValueChanged() {
    this.drawWorkflow()
  }

  transitionsValueChanged() {
    this.drawWorkflow()
  }

  drawWorkflow() {
    if (!this.hasCanvasTarget || !this.statesValue || this.statesValue.length === 0) {
      return
    }

    // Clear existing SVG content
    this.canvasTarget.innerHTML = ""

    // Set SVG dimensions
    this.canvasTarget.style.width = `${this.widthValue}px`
    this.canvasTarget.style.height = `${this.heightValue}px`
    this.canvasTarget.setAttribute("viewBox", `0 0 ${this.widthValue} ${this.heightValue}`)

    // Sort states by position
    const sortedStates = [...this.statesValue].sort((a, b) => (a.position || 0) - (b.position || 0))

    // Calculate positions for states
    const statePositions = this.calculateStatePositions(sortedStates)

    // Draw transitions first (so they appear behind states)
    this.drawTransitions(statePositions)

    // Draw states on top
    this.drawStates(statePositions)
  }

  calculateStatePositions(states) {
    const positions = new Map()
    const padding = 60
    const stateWidth = 120
    const stateHeight = 60

    if (states.length === 1) {
      // Single state centered
      positions.set(states[0].id, {
        x: this.widthValue / 2,
        y: this.heightValue / 2,
        state: states[0]
      })
    } else if (states.length <= 4) {
      // Linear layout for small workflows
      const availableWidth = this.widthValue - (2 * padding)
      const spacing = availableWidth / (states.length - 1)

      states.forEach((state, index) => {
        positions.set(state.id, {
          x: padding + (index * spacing),
          y: this.heightValue / 2,
          state: state
        })
      })
    } else {
      // Grid layout for larger workflows
      const cols = Math.ceil(Math.sqrt(states.length))
      const rows = Math.ceil(states.length / cols)
      const colSpacing = (this.widthValue - (2 * padding)) / (cols - 1 || 1)
      const rowSpacing = (this.heightValue - (2 * padding)) / (rows - 1 || 1)

      states.forEach((state, index) => {
        const col = index % cols
        const row = Math.floor(index / cols)
        positions.set(state.id, {
          x: padding + (col * colSpacing),
          y: padding + (row * rowSpacing),
          state: state
        })
      })
    }

    return positions
  }

  drawStates(statePositions) {
    statePositions.forEach(({ x, y, state }) => {
      const group = this.createSVGElement("g")
      group.setAttribute("class", "workflow-state")
      group.setAttribute("data-state-id", state.id)

      // State circle/rectangle
      const rect = this.createSVGElement("rect")
      rect.setAttribute("x", x - 60)
      rect.setAttribute("y", y - 25)
      rect.setAttribute("width", "120")
      rect.setAttribute("height", "50")
      rect.setAttribute("rx", "8")
      rect.setAttribute("fill", state.color || "#e5e7eb")
      rect.setAttribute("stroke", this.getStateStrokeColor(state))
      rect.setAttribute("stroke-width", state.is_initial ? "3" : "2")
      rect.setAttribute("class", "workflow-state-rect")

      // State text
      const text = this.createSVGElement("text")
      text.setAttribute("x", x)
      text.setAttribute("y", y)
      text.setAttribute("text-anchor", "middle")
      text.setAttribute("dominant-baseline", "middle")
      text.setAttribute("class", "workflow-state-text")
      text.setAttribute("fill", this.getTextColor(state.color))
      text.setAttribute("font-size", "12")
      text.setAttribute("font-weight", "500")
      text.textContent = this.truncateText(state.display_name || state.name, 15)

      // Add badges for special states
      if (state.is_initial || state.is_final || state.is_error) {
        const badge = this.createStateBadge(x, y - 35, state)
        group.appendChild(badge)
      }

      group.appendChild(rect)
      group.appendChild(text)
      this.canvasTarget.appendChild(group)
    })
  }

  drawTransitions(statePositions) {
    if (!this.transitionsValue) return

    this.transitionsValue.forEach(transition => {
      const fromPos = statePositions.get(transition.from_state_id)
      const toPos = statePositions.get(transition.to_state_id)

      if (!fromPos || !toPos) return

      const group = this.createSVGElement("g")
      group.setAttribute("class", "workflow-transition")
      group.setAttribute("data-transition-id", transition.id)

      // Calculate arrow path
      const { path, arrowX, arrowY, angle } = this.calculateArrowPath(fromPos, toPos)

      // Transition line
      const line = this.createSVGElement("path")
      line.setAttribute("d", path)
      line.setAttribute("stroke", "#6b7280")
      line.setAttribute("stroke-width", "2")
      line.setAttribute("fill", "none")
      line.setAttribute("marker-end", "url(#arrowhead)")

      // Arrow marker
      if (!document.getElementById("arrowhead")) {
        this.createArrowMarker()
      }

      // Transition label
      const midX = (fromPos.x + toPos.x) / 2
      const midY = (fromPos.y + toPos.y) / 2 - 10

      const labelBg = this.createSVGElement("rect")
      const labelText = transition.display_name || transition.name
      const textWidth = labelText.length * 6 + 8

      labelBg.setAttribute("x", midX - textWidth/2)
      labelBg.setAttribute("y", midY - 8)
      labelBg.setAttribute("width", textWidth)
      labelBg.setAttribute("height", "16")
      labelBg.setAttribute("fill", "white")
      labelBg.setAttribute("stroke", "#d1d5db")
      labelBg.setAttribute("rx", "3")

      const label = this.createSVGElement("text")
      label.setAttribute("x", midX)
      label.setAttribute("y", midY)
      label.setAttribute("text-anchor", "middle")
      label.setAttribute("dominant-baseline", "middle")
      label.setAttribute("font-size", "10")
      label.setAttribute("fill", "#374151")
      label.textContent = this.truncateText(labelText, 12)

      group.appendChild(line)
      group.appendChild(labelBg)
      group.appendChild(label)
      this.canvasTarget.appendChild(group)
    })
  }

  calculateArrowPath(fromPos, toPos) {
    // Simple straight line for now
    const dx = toPos.x - fromPos.x
    const dy = toPos.y - fromPos.y
    const distance = Math.sqrt(dx * dx + dy * dy)

    // Adjust start and end points to account for state box size
    const stateRadius = 60
    const startRatio = stateRadius / distance
    const endRatio = (distance - stateRadius) / distance

    const startX = fromPos.x + dx * startRatio
    const startY = fromPos.y + dy * startRatio
    const endX = fromPos.x + dx * endRatio
    const endY = fromPos.y + dy * endRatio

    return {
      path: `M ${startX} ${startY} L ${endX} ${endY}`,
      arrowX: endX,
      arrowY: endY,
      angle: Math.atan2(dy, dx) * 180 / Math.PI
    }
  }

  createStateBadge(x, y, state) {
    const group = this.createSVGElement("g")

    let badgeText = ""
    let badgeColor = "#6b7280"

    if (state.is_initial) {
      badgeText = "START"
      badgeColor = "#059669"
    } else if (state.is_final) {
      badgeText = "END"
      badgeColor = "#2563eb"
    } else if (state.is_error) {
      badgeText = "ERROR"
      badgeColor = "#dc2626"
    }

    if (badgeText) {
      const badge = this.createSVGElement("rect")
      badge.setAttribute("x", x - 15)
      badge.setAttribute("y", y - 6)
      badge.setAttribute("width", "30")
      badge.setAttribute("height", "12")
      badge.setAttribute("rx", "6")
      badge.setAttribute("fill", badgeColor)

      const text = this.createSVGElement("text")
      text.setAttribute("x", x)
      text.setAttribute("y", y)
      text.setAttribute("text-anchor", "middle")
      text.setAttribute("dominant-baseline", "middle")
      text.setAttribute("font-size", "8")
      text.setAttribute("font-weight", "bold")
      text.setAttribute("fill", "white")
      text.textContent = badgeText

      group.appendChild(badge)
      group.appendChild(text)
    }

    return group
  }

  createArrowMarker() {
    const defs = this.createSVGElement("defs")
    const marker = this.createSVGElement("marker")
    marker.setAttribute("id", "arrowhead")
    marker.setAttribute("markerWidth", "10")
    marker.setAttribute("markerHeight", "7")
    marker.setAttribute("refX", "9")
    marker.setAttribute("refY", "3.5")
    marker.setAttribute("orient", "auto")

    const polygon = this.createSVGElement("polygon")
    polygon.setAttribute("points", "0 0, 10 3.5, 0 7")
    polygon.setAttribute("fill", "#6b7280")

    marker.appendChild(polygon)
    defs.appendChild(marker)
    this.canvasTarget.appendChild(defs)
  }

  getStateStrokeColor(state) {
    if (state.is_initial) return "#059669"
    if (state.is_final) return "#2563eb"
    if (state.is_error) return "#dc2626"
    return "#9ca3af"
  }

  getTextColor(backgroundColor) {
    // Simple logic to determine if text should be dark or light
    if (!backgroundColor || backgroundColor === '#gray') return "#374151"

    // Convert hex to RGB and calculate brightness
    const hex = backgroundColor.replace('#', '')
    if (hex.length === 3) {
      const r = parseInt(hex[0] + hex[0], 16)
      const g = parseInt(hex[1] + hex[1], 16)
      const b = parseInt(hex[2] + hex[2], 16)
      const brightness = (r * 299 + g * 587 + b * 114) / 1000
      return brightness > 128 ? "#374151" : "#ffffff"
    } else if (hex.length === 6) {
      const r = parseInt(hex.substr(0, 2), 16)
      const g = parseInt(hex.substr(2, 2), 16)
      const b = parseInt(hex.substr(4, 2), 16)
      const brightness = (r * 299 + g * 587 + b * 114) / 1000
      return brightness > 128 ? "#374151" : "#ffffff"
    }

    return "#374151"
  }

  truncateText(text, maxLength) {
    if (text.length <= maxLength) return text
    return text.substr(0, maxLength - 3) + "..."
  }

  createSVGElement(tagName) {
    return document.createElementNS("http://www.w3.org/2000/svg", tagName)
  }
}