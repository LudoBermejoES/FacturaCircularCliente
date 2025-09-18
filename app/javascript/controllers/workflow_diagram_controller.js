import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="workflow-diagram"
export default class extends Controller {
  static targets = ["canvas", "normalCanvas", "fullscreenOverlay", "maximizeBtn", "diagramContainer"]
  static values = {
    states: Array,
    transitions: Array,
    width: { type: Number, default: 800 },
    height: { type: Number, default: 400 }
  }

  connect() {
    this.isMaximized = false
    this.currentCanvas = this.hasNormalCanvasTarget ? this.normalCanvasTarget : this.canvasTarget
    this.drawWorkflow()

    // Handle escape key to exit fullscreen
    this.handleEscape = (event) => {
      if (event.key === 'Escape' && this.isMaximized) {
        this.toggleMaximize()
      }
    }
    document.addEventListener('keydown', this.handleEscape)
  }

  disconnect() {
    document.removeEventListener('keydown', this.handleEscape)
  }

  statesValueChanged() {
    this.drawWorkflow()
  }

  transitionsValueChanged() {
    this.drawWorkflow()
  }

  toggleMaximize() {
    this.isMaximized = !this.isMaximized

    if (this.isMaximized) {
      // Switch to fullscreen mode
      this.fullscreenOverlayTarget.classList.remove('hidden')
      this.currentCanvas = this.canvasTarget
      document.body.style.overflow = 'hidden'
    } else {
      // Switch back to normal mode
      this.fullscreenOverlayTarget.classList.add('hidden')
      this.currentCanvas = this.normalCanvasTarget
      document.body.style.overflow = ''
    }

    // Redraw with new dimensions
    this.drawWorkflow()
  }

  drawWorkflow() {
    if (!this.currentCanvas || !this.statesValue || this.statesValue.length === 0) {
      return
    }

    // Clear existing SVG content
    this.currentCanvas.innerHTML = ""

    // Calculate dimensions based on mode
    let drawWidth, drawHeight

    if (this.isMaximized) {
      // Use viewport dimensions for maximized mode
      drawWidth = window.innerWidth - 100
      drawHeight = window.innerHeight - 200
    } else {
      // Use default dimensions for normal mode
      drawWidth = this.widthValue
      drawHeight = this.heightValue
    }

    // Dynamically calculate height based on content
    const minHeight = Math.ceil(this.statesValue.length / 3) * 150 + 100
    const dynamicHeight = Math.max(drawHeight, minHeight)

    // Set SVG dimensions
    this.currentCanvas.style.width = `${drawWidth}px`
    this.currentCanvas.style.height = `${dynamicHeight}px`
    this.currentCanvas.setAttribute("viewBox", `0 0 ${drawWidth} ${dynamicHeight}`)

    // Store dimensions for layout calculations
    this.drawWidth = drawWidth
    this.drawHeight = dynamicHeight

    // Sort states by position
    const sortedStates = [...this.statesValue].sort((a, b) => (a.position || 0) - (b.position || 0))

    // Calculate positions for states with better layout
    const statePositions = this.calculateSmartStatePositions(sortedStates)

    // Create arrow markers first
    this.createArrowMarkers()

    // Draw transitions first (so they appear behind states)
    this.drawEnhancedTransitions(statePositions)

    // Draw states on top
    this.drawStates(statePositions)
  }

  calculateSmartStatePositions(states) {
    const positions = new Map()
    const padding = this.isMaximized ? 120 : 80
    const stateWidth = this.isMaximized ? 160 : 140
    const stateHeight = this.isMaximized ? 80 : 70
    const verticalSpacing = this.isMaximized ? 50 : 30

    // Create a map for quick code-to-state lookup
    const statesByCode = new Map()
    states.forEach(state => {
      statesByCode.set(state.code, state)
    })

    // Identify initial, final, and error states
    const initialStates = states.filter(s => s.is_initial)
    const finalStates = states.filter(s => s.is_final)
    const errorStates = states.filter(s => s.is_error && !s.is_final)
    const middleStates = states.filter(s => !s.is_initial && !s.is_final && !s.is_error)

    // Layout algorithm based on workflow phases
    if (states.length === 1) {
      // Single state centered
      positions.set(states[0].id, {
        x: this.drawWidth / 2,
        y: this.drawHeight / 2,
        state: states[0]
      })
    } else {
      // Multi-phase layout
      let currentY = padding

      // Phase 1: Initial states (leftmost)
      if (initialStates.length > 0) {
        const startY = (this.drawHeight - initialStates.length * (stateHeight + verticalSpacing)) / 2
        initialStates.forEach((state, index) => {
          positions.set(state.id, {
            x: padding,
            y: startY + (index * (stateHeight + verticalSpacing)),
            state: state
          })
        })
        currentY = padding
      }

      // Phase 2: Middle states (distributed in columns)
      if (middleStates.length > 0) {
        const cols = Math.min(this.isMaximized ? 4 : 3, Math.ceil(Math.sqrt(middleStates.length)))
        const rows = Math.ceil(middleStates.length / cols)

        const startX = padding + stateWidth + 60
        const endX = this.drawWidth - padding - stateWidth - 60
        const colSpacing = (endX - startX) / Math.max(1, cols - 1)

        const startY = (this.drawHeight - rows * (stateHeight + verticalSpacing)) / 2

        middleStates.forEach((state, index) => {
          const col = index % cols
          const row = Math.floor(index / cols)
          positions.set(state.id, {
            x: startX + (col * colSpacing),
            y: startY + (row * (stateHeight + verticalSpacing)),
            state: state
          })
        })
      }

      // Phase 3: Final and Error states (rightmost)
      const rightStates = [...finalStates, ...errorStates]
      if (rightStates.length > 0) {
        const startY = (this.drawHeight - rightStates.length * (stateHeight + verticalSpacing)) / 2
        rightStates.forEach((state, index) => {
          positions.set(state.id, {
            x: this.drawWidth - padding,
            y: startY + (index * (stateHeight + verticalSpacing)),
            state: state
          })
        })
      }
    }

    // Adjust positions to avoid overlaps
    this.adjustPositionsForTransitions(positions)

    return positions
  }

  adjustPositionsForTransitions(positions) {
    // Simple adjustment to spread out states if they're too close
    const minDistance = this.isMaximized ? 120 : 100
    const posArray = Array.from(positions.values())

    for (let i = 0; i < posArray.length; i++) {
      for (let j = i + 1; j < posArray.length; j++) {
        const pos1 = posArray[i]
        const pos2 = posArray[j]
        const dx = pos2.x - pos1.x
        const dy = pos2.y - pos1.y
        const distance = Math.sqrt(dx * dx + dy * dy)

        if (distance < minDistance && distance > 0) {
          // Spread them apart
          const factor = minDistance / distance
          pos2.y += dy * (factor - 1) * 0.5
        }
      }
    }
  }

  drawStates(statePositions) {
    const stateWidth = this.isMaximized ? 75 : 65
    const stateHeight = this.isMaximized ? 32 : 28
    const fontSize = this.isMaximized ? 14 : 13
    const codeFontSize = this.isMaximized ? 11 : 10

    statePositions.forEach(({ x, y, state }) => {
      const group = this.createSVGElement("g")
      group.setAttribute("class", "workflow-state cursor-pointer hover:opacity-90 transition-opacity")
      group.setAttribute("data-state-id", state.id)

      // Drop shadow for depth
      const shadow = this.createSVGElement("rect")
      shadow.setAttribute("x", x - stateWidth)
      shadow.setAttribute("y", y - stateHeight)
      shadow.setAttribute("width", stateWidth * 2)
      shadow.setAttribute("height", stateHeight * 2)
      shadow.setAttribute("rx", "12")
      shadow.setAttribute("fill", "rgba(0,0,0,0.1)")
      shadow.setAttribute("transform", "translate(2, 2)")

      // State rectangle with gradient
      const rect = this.createSVGElement("rect")
      rect.setAttribute("x", x - stateWidth)
      rect.setAttribute("y", y - stateHeight)
      rect.setAttribute("width", stateWidth * 2)
      rect.setAttribute("height", stateHeight * 2)
      rect.setAttribute("rx", "12")
      rect.setAttribute("fill", state.color || "#f3f4f6")
      rect.setAttribute("stroke", this.getStateStrokeColor(state))
      rect.setAttribute("stroke-width", state.is_initial ? "3" : "2")
      rect.setAttribute("class", "workflow-state-rect")

      // State icon based on type
      const iconX = x - stateWidth + 10
      const iconY = y - stateHeight + 10
      const icon = this.createStateIcon(iconX, iconY, state)

      // State text
      const text = this.createSVGElement("text")
      text.setAttribute("x", x - stateWidth + 30)
      text.setAttribute("y", y - 5)
      text.setAttribute("text-anchor", "start")
      text.setAttribute("dominant-baseline", "middle")
      text.setAttribute("class", "workflow-state-text")
      text.setAttribute("fill", this.getTextColor(state.color))
      text.setAttribute("font-size", fontSize)
      text.setAttribute("font-weight", "600")
      text.textContent = this.truncateText(state.name || state.display_name, this.isMaximized ? 16 : 12)

      // State code (smaller text below)
      const codeText = this.createSVGElement("text")
      codeText.setAttribute("x", x - stateWidth + 30)
      codeText.setAttribute("y", y + 10)
      codeText.setAttribute("text-anchor", "start")
      codeText.setAttribute("dominant-baseline", "middle")
      codeText.setAttribute("fill", this.getTextColor(state.color))
      codeText.setAttribute("font-size", codeFontSize)
      codeText.setAttribute("opacity", "0.7")
      codeText.textContent = state.code

      // Add badges for special states
      if (state.is_initial || state.is_final || state.is_error) {
        const badge = this.createStateBadge(x, y - (this.isMaximized ? 48 : 42), state)
        group.appendChild(badge)
      }

      group.appendChild(shadow)
      group.appendChild(rect)
      if (icon) group.appendChild(icon)
      group.appendChild(text)
      group.appendChild(codeText)
      this.currentCanvas.appendChild(group)

      // Add hover effect
      group.addEventListener('mouseenter', () => {
        rect.setAttribute("filter", "brightness(1.1)")
      })
      group.addEventListener('mouseleave', () => {
        rect.removeAttribute("filter")
      })
    })
  }

  drawEnhancedTransitions(statePositions) {
    if (!this.transitionsValue || this.transitionsValue.length === 0) return

    // Group transitions to handle multiple transitions between same states
    const transitionGroups = new Map()

    this.transitionsValue.forEach(transition => {
      // Find states by matching codes
      let fromState = null
      let toState = null

      statePositions.forEach((pos) => {
        if (pos.state.code === transition.from_state_code) {
          fromState = pos
        }
        if (pos.state.code === transition.to_state_code) {
          toState = pos
        }
      })

      // Handle "from any state" transitions
      if (!transition.from_state_code || transition.from_state_code === 'any') {
        // Draw from multiple states to the target
        statePositions.forEach((fromPos) => {
          if (fromPos.state.code !== transition.to_state_code && toState) {
            this.drawSingleTransition(fromPos, toState, transition, true)
          }
        })
      } else if (fromState && toState) {
        const key = `${fromState.state.id}-${toState.state.id}`
        if (!transitionGroups.has(key)) {
          transitionGroups.set(key, [])
        }
        transitionGroups.get(key).push({ fromState, toState, transition })
      }
    })

    // Draw grouped transitions with proper curves
    transitionGroups.forEach((transitions, key) => {
      transitions.forEach((t, index) => {
        const offset = (index - (transitions.length - 1) / 2) * 20
        this.drawSingleTransition(t.fromState, t.toState, t.transition, false, offset)
      })
    })
  }

  drawSingleTransition(fromPos, toPos, transition, isDashed = false, curveOffset = 0) {
    const group = this.createSVGElement("g")
    group.setAttribute("class", "workflow-transition")
    group.setAttribute("data-transition-id", transition.id)

    // Calculate curved arrow path
    const path = this.calculateCurvedArrowPath(fromPos, toPos, curveOffset)

    // Transition line
    const line = this.createSVGElement("path")
    line.setAttribute("d", path)
    line.setAttribute("stroke", isDashed ? "#9ca3af" : "#6b7280")
    line.setAttribute("stroke-width", isDashed ? "1.5" : "2")
    line.setAttribute("fill", "none")
    line.setAttribute("marker-end", isDashed ? "url(#arrowhead-dashed)" : "url(#arrowhead)")
    if (isDashed) {
      line.setAttribute("stroke-dasharray", "5,5")
    }

    // Calculate label position on the curve
    const { labelX, labelY } = this.getPointOnPath(fromPos, toPos, 0.5, curveOffset)

    // Transition label with better background
    if (transition.name && !isDashed) {
      const labelGroup = this.createSVGElement("g")
      const labelText = transition.name || transition.display_name
      const fontSize = this.isMaximized ? 12 : 11
      const textWidth = Math.min(this.isMaximized ? 120 : 100, labelText.length * 7 + 10)

      // Label background with border
      const labelBg = this.createSVGElement("rect")
      labelBg.setAttribute("x", labelX - textWidth/2)
      labelBg.setAttribute("y", labelY - 10)
      labelBg.setAttribute("width", textWidth)
      labelBg.setAttribute("height", "20")
      labelBg.setAttribute("fill", "white")
      labelBg.setAttribute("stroke", "#e5e7eb")
      labelBg.setAttribute("stroke-width", "1")
      labelBg.setAttribute("rx", "4")

      const label = this.createSVGElement("text")
      label.setAttribute("x", labelX)
      label.setAttribute("y", labelY)
      label.setAttribute("text-anchor", "middle")
      label.setAttribute("dominant-baseline", "middle")
      label.setAttribute("font-size", fontSize)
      label.setAttribute("fill", "#4b5563")
      label.setAttribute("font-weight", "500")
      label.textContent = this.truncateText(labelText, this.isMaximized ? 18 : 14)

      // Add role badges if present
      if (transition.required_roles && transition.required_roles.length > 0) {
        const roleText = this.createSVGElement("text")
        roleText.setAttribute("x", labelX)
        roleText.setAttribute("y", labelY + 15)
        roleText.setAttribute("text-anchor", "middle")
        roleText.setAttribute("font-size", this.isMaximized ? 10 : 9)
        roleText.setAttribute("fill", "#9ca3af")
        roleText.textContent = `[${transition.required_roles.join(', ')}]`
        labelGroup.appendChild(roleText)
      }

      labelGroup.appendChild(labelBg)
      labelGroup.appendChild(label)
      group.appendChild(labelGroup)
    }

    group.appendChild(line)
    this.currentCanvas.insertBefore(group, this.currentCanvas.firstChild)
  }

  calculateCurvedArrowPath(fromPos, toPos, curveOffset = 0) {
    const stateWidth = this.isMaximized ? 75 : 65
    const stateHeight = this.isMaximized ? 32 : 28

    const dx = toPos.x - fromPos.x
    const dy = toPos.y - fromPos.y
    const distance = Math.sqrt(dx * dx + dy * dy)

    // Calculate edge points considering rectangle shape
    const fromAngle = Math.atan2(dy, dx)
    const toAngle = fromAngle + Math.PI

    const fromEdge = this.getRectangleEdgePoint(fromPos.x, fromPos.y, stateWidth, stateHeight, fromAngle)
    const toEdge = this.getRectangleEdgePoint(toPos.x, toPos.y, stateWidth, stateHeight, toAngle)

    // Self-loop handling
    if (distance < 50) {
      const loopSize = this.isMaximized ? 50 : 40
      return `M ${fromEdge.x} ${fromEdge.y}
              C ${fromEdge.x - loopSize} ${fromEdge.y - loopSize * 2},
                ${toEdge.x + loopSize} ${toEdge.y - loopSize * 2},
                ${toEdge.x} ${toEdge.y}`
    }

    // Calculate control points for curved path
    const midX = (fromEdge.x + toEdge.x) / 2
    const midY = (fromEdge.y + toEdge.y) / 2

    // Add curve based on distance and offset
    const curveFactor = Math.min(0.3, 100 / distance)
    const perpX = -dy / distance * (50 + Math.abs(curveOffset))
    const perpY = dx / distance * (50 + Math.abs(curveOffset))

    const controlX = midX + perpX * curveFactor * Math.sign(curveOffset || 1)
    const controlY = midY + perpY * curveFactor * Math.sign(curveOffset || 1)

    return `M ${fromEdge.x} ${fromEdge.y} Q ${controlX} ${controlY} ${toEdge.x} ${toEdge.y}`
  }

  getRectangleEdgePoint(cx, cy, halfWidth, halfHeight, angle) {
    const cos = Math.cos(angle)
    const sin = Math.sin(angle)

    // Find intersection with rectangle edge
    let x, y
    if (Math.abs(cos) * halfHeight > Math.abs(sin) * halfWidth) {
      // Intersects vertical edge
      x = cx + halfWidth * Math.sign(cos)
      y = cy + halfWidth * Math.tan(angle) * Math.sign(cos)
    } else {
      // Intersects horizontal edge
      x = cx + halfHeight / Math.tan(angle) * Math.sign(sin)
      y = cy + halfHeight * Math.sign(sin)
    }

    return { x, y }
  }

  getPointOnPath(fromPos, toPos, t, curveOffset = 0) {
    const stateWidth = this.isMaximized ? 75 : 65
    const stateHeight = this.isMaximized ? 32 : 28

    // Calculate point on quadratic Bezier curve
    const fromEdge = this.getRectangleEdgePoint(fromPos.x, fromPos.y, stateWidth, stateHeight,
                                                Math.atan2(toPos.y - fromPos.y, toPos.x - fromPos.x))
    const toEdge = this.getRectangleEdgePoint(toPos.x, toPos.y, stateWidth, stateHeight,
                                              Math.atan2(fromPos.y - toPos.y, fromPos.x - toPos.x))

    const dx = toPos.x - fromPos.x
    const dy = toPos.y - fromPos.y
    const distance = Math.sqrt(dx * dx + dy * dy)

    const midX = (fromEdge.x + toEdge.x) / 2
    const midY = (fromEdge.y + toEdge.y) / 2

    const curveFactor = Math.min(0.3, 100 / distance)
    const perpX = -dy / distance * (50 + Math.abs(curveOffset))
    const perpY = dx / distance * (50 + Math.abs(curveOffset))

    const controlX = midX + perpX * curveFactor * Math.sign(curveOffset || 1)
    const controlY = midY + perpY * curveFactor * Math.sign(curveOffset || 1)

    // Quadratic Bezier formula
    const labelX = (1 - t) * (1 - t) * fromEdge.x + 2 * (1 - t) * t * controlX + t * t * toEdge.x
    const labelY = (1 - t) * (1 - t) * fromEdge.y + 2 * (1 - t) * t * controlY + t * t * toEdge.y

    return { labelX, labelY }
  }

  createStateIcon(x, y, state) {
    const icon = this.createSVGElement("g")
    const scale = this.isMaximized ? 1.2 : 1

    if (state.is_initial) {
      // Play button icon for initial
      const path = this.createSVGElement("path")
      path.setAttribute("d", "M 0 0 L 10 6 L 0 12 Z")
      path.setAttribute("transform", `translate(${x}, ${y}) scale(${scale})`)
      path.setAttribute("fill", "#059669")
      icon.appendChild(path)
    } else if (state.is_final) {
      // Checkmark icon for final
      const path = this.createSVGElement("path")
      path.setAttribute("d", "M 0 6 L 4 10 L 12 2")
      path.setAttribute("transform", `translate(${x}, ${y}) scale(${scale})`)
      path.setAttribute("stroke", "#2563eb")
      path.setAttribute("stroke-width", "2")
      path.setAttribute("fill", "none")
      path.setAttribute("stroke-linecap", "round")
      path.setAttribute("stroke-linejoin", "round")
      icon.appendChild(path)
    } else if (state.is_error) {
      // X icon for error
      const path1 = this.createSVGElement("path")
      path1.setAttribute("d", "M 0 0 L 10 10 M 10 0 L 0 10")
      path1.setAttribute("transform", `translate(${x}, ${y + 3}) scale(${scale})`)
      path1.setAttribute("stroke", "#dc2626")
      path1.setAttribute("stroke-width", "2")
      path1.setAttribute("stroke-linecap", "round")
      icon.appendChild(path1)
    } else {
      // Default circle icon
      const circle = this.createSVGElement("circle")
      circle.setAttribute("cx", x + 5)
      circle.setAttribute("cy", y + 6)
      circle.setAttribute("r", 4 * scale)
      circle.setAttribute("fill", "#9ca3af")
      circle.setAttribute("opacity", "0.5")
      icon.appendChild(circle)
    }

    return icon
  }

  createStateBadge(x, y, state) {
    const group = this.createSVGElement("g")

    let badgeText = ""
    let badgeColor = "#6b7280"
    let badgeWidth = this.isMaximized ? 45 : 40

    if (state.is_initial) {
      badgeText = "START"
      badgeColor = "#059669"
    } else if (state.is_final) {
      badgeText = "FINAL"
      badgeColor = "#2563eb"
      badgeWidth = this.isMaximized ? 40 : 35
    } else if (state.is_error) {
      badgeText = "ERROR"
      badgeColor = "#dc2626"
    }

    if (badgeText) {
      const badge = this.createSVGElement("rect")
      badge.setAttribute("x", x - badgeWidth/2)
      badge.setAttribute("y", y - 8)
      badge.setAttribute("width", badgeWidth)
      badge.setAttribute("height", "16")
      badge.setAttribute("rx", "8")
      badge.setAttribute("fill", badgeColor)

      const text = this.createSVGElement("text")
      text.setAttribute("x", x)
      text.setAttribute("y", y)
      text.setAttribute("text-anchor", "middle")
      text.setAttribute("dominant-baseline", "middle")
      text.setAttribute("font-size", this.isMaximized ? 10 : 9)
      text.setAttribute("font-weight", "bold")
      text.setAttribute("fill", "white")
      text.textContent = badgeText

      group.appendChild(badge)
      group.appendChild(text)
    }

    return group
  }

  createArrowMarkers() {
    const defs = this.createSVGElement("defs")

    // Regular arrow
    const marker = this.createSVGElement("marker")
    marker.setAttribute("id", "arrowhead")
    marker.setAttribute("markerWidth", "10")
    marker.setAttribute("markerHeight", "10")
    marker.setAttribute("refX", "8")
    marker.setAttribute("refY", "5")
    marker.setAttribute("orient", "auto")

    const polygon = this.createSVGElement("polygon")
    polygon.setAttribute("points", "0 0, 10 5, 0 10")
    polygon.setAttribute("fill", "#6b7280")

    marker.appendChild(polygon)
    defs.appendChild(marker)

    // Dashed arrow for "any state" transitions
    const dashedMarker = this.createSVGElement("marker")
    dashedMarker.setAttribute("id", "arrowhead-dashed")
    dashedMarker.setAttribute("markerWidth", "10")
    dashedMarker.setAttribute("markerHeight", "10")
    dashedMarker.setAttribute("refX", "8")
    dashedMarker.setAttribute("refY", "5")
    dashedMarker.setAttribute("orient", "auto")

    const dashedPolygon = this.createSVGElement("polygon")
    dashedPolygon.setAttribute("points", "0 0, 10 5, 0 10")
    dashedPolygon.setAttribute("fill", "#9ca3af")

    dashedMarker.appendChild(dashedPolygon)
    defs.appendChild(dashedMarker)

    this.currentCanvas.appendChild(defs)
  }

  getStateStrokeColor(state) {
    if (state.is_initial) return "#059669"
    if (state.is_final) return "#2563eb"
    if (state.is_error) return "#dc2626"
    return "#d1d5db"
  }

  getTextColor(backgroundColor) {
    // Simple logic to determine if text should be dark or light
    if (!backgroundColor || backgroundColor === '#gray' || backgroundColor === '#f3f4f6') return "#374151"

    // Convert hex to RGB and calculate brightness
    const hex = backgroundColor.replace('#', '')
    let r, g, b

    if (hex.length === 3) {
      r = parseInt(hex[0] + hex[0], 16)
      g = parseInt(hex[1] + hex[1], 16)
      b = parseInt(hex[2] + hex[2], 16)
    } else if (hex.length === 6) {
      r = parseInt(hex.substr(0, 2), 16)
      g = parseInt(hex.substr(2, 2), 16)
      b = parseInt(hex.substr(4, 2), 16)
    } else {
      return "#374151"
    }

    const brightness = (r * 299 + g * 587 + b * 114) / 1000
    return brightness > 155 ? "#374151" : "#ffffff"
  }

  truncateText(text, maxLength) {
    if (!text) return ""
    if (text.length <= maxLength) return text
    return text.substr(0, maxLength - 2) + ".."
  }

  createSVGElement(tagName) {
    return document.createElementNS("http://www.w3.org/2000/svg", tagName)
  }
}