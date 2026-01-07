class HillChart {
  constructor(element, options = {}) {
    this.element = element;
    this.width = options.width || 400;
    this.height = options.height || 200;
    this.editable = options.editable || false;
    this.dots = options.dots || [];
    this.truncateLength = options.truncateLength || 20;
    this.mode = 'view';
    this.currentDrag = null;
    this.dirtyDots = new Set();
    this.originalPositions = new Map();
    
    this.init();
    this.setupGlobalDragHandlers();
  }

  init() {
    this.element.innerHTML = '';
    this.createSVG();
    this.createControls();
    this.render();
  }

  createSVG() {
    this.svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    this.svg.setAttribute('width', this.width);
    this.svg.setAttribute('height', this.height);
    this.svg.setAttribute('class', 'hillchart-svg');
    this.svg.style.cssText = 'border: 1px solid var(--hillchart-border, #d1d5db); border-radius: var(--hillchart-radius, 6px); background: var(--hillchart-bg, #ffffff);';
    this.element.appendChild(this.svg);
    
    this.drawHill();
  }

  drawHill() {
    const midX = this.width / 2;
    const computedStyle = getComputedStyle(document.documentElement);
    const marginRatio = parseFloat(computedStyle.getPropertyValue('--hillchart-margin-ratio') || '0.15');
    const sigma = parseFloat(computedStyle.getPropertyValue('--hillchart-gaussian-sigma') || '0.3');
    const margin = this.height * marginRatio;
    const baseY = this.height - margin;
    const peakY = margin;
    
    const curveStep = parseFloat(computedStyle.getPropertyValue('--hillchart-curve-step') || '5');
    const baselineOffset = parseFloat(computedStyle.getPropertyValue('--hillchart-baseline-offset') || '2');
    const labelOffset = parseFloat(computedStyle.getPropertyValue('--hillchart-label-offset') || '20');
    const labelMinMargin = parseFloat(computedStyle.getPropertyValue('--hillchart-label-min-margin') || '10');
    
    // Generate Gaussian curve points
    const points = [];
    for (let x = 0; x <= this.width; x += curveStep) {
      const y = this.getYForX(x, marginRatio, sigma);
      points.push(`${x},${y}`);
    }
    
    // Create full background
    const fullBg = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
    fullBg.setAttribute('width', this.width);
    fullBg.setAttribute('height', this.height);
    fullBg.setAttribute('fill', 'var(--hillchart-hill-bg, #f8f9fa)');
    this.svg.appendChild(fullBg);
    
    // Create hill line
    const hillPath = document.createElementNS('http://www.w3.org/2000/svg', 'polyline');
    hillPath.setAttribute('points', points.join(' '));
    hillPath.setAttribute('stroke', 'var(--hillchart-hill-stroke, #4b5563)');
    hillPath.setAttribute('stroke-width', 'var(--hillchart-hill-stroke-width, 3px)');
    hillPath.setAttribute('fill', 'none');
    
    this.svg.appendChild(hillPath);
    
    // Add center line
    const centerLine = document.createElementNS('http://www.w3.org/2000/svg', 'line');
    centerLine.setAttribute('x1', midX);
    centerLine.setAttribute('y1', peakY);
    centerLine.setAttribute('x2', midX);
    centerLine.setAttribute('y2', baseY);
    centerLine.setAttribute('stroke', 'var(--hillchart-center-line-stroke, #9ca3af)');
    centerLine.setAttribute('stroke-width', 'var(--hillchart-center-line-width, 1px)');
    centerLine.setAttribute('stroke-dasharray', '3,3');
    this.svg.appendChild(centerLine);
    
    // Add baseline at curve endpoints
    const curveEndY = this.getYForX(0, marginRatio, sigma);
    const baseline = document.createElementNS('http://www.w3.org/2000/svg', 'line');
    baseline.setAttribute('x1', 0);
    baseline.setAttribute('y1', curveEndY + baselineOffset);
    baseline.setAttribute('x2', this.width);
    baseline.setAttribute('y2', curveEndY + baselineOffset);
    baseline.setAttribute('stroke', 'var(--hillchart-baseline-stroke, #9ca3af)');
    baseline.setAttribute('stroke-width', 'var(--hillchart-baseline-width, 1px)');
    baseline.setAttribute('stroke-dasharray', '3,3');
    this.svg.appendChild(baseline);
    
    // Add phase labels
    const labelY = Math.min(curveEndY + labelOffset, this.height - labelMinMargin);
    const leftLabel = document.createElementNS('http://www.w3.org/2000/svg', 'text');
    leftLabel.setAttribute('x', midX / 2);
    leftLabel.setAttribute('y', labelY);
    leftLabel.setAttribute('text-anchor', 'middle');
    leftLabel.setAttribute('font-size', 'var(--hillchart-label-font-size, 12px)');
    leftLabel.setAttribute('font-weight', 'var(--hillchart-label-font-weight, 600)');
    leftLabel.setAttribute('fill', 'var(--hillchart-label-color, #6b7280)');
    leftLabel.textContent = 'FIGURING THINGS OUT';
    this.svg.appendChild(leftLabel);
    
    const rightLabel = document.createElementNS('http://www.w3.org/2000/svg', 'text');
    rightLabel.setAttribute('x', midX + midX / 2);
    rightLabel.setAttribute('y', labelY);
    rightLabel.setAttribute('text-anchor', 'middle');
    rightLabel.setAttribute('font-size', 'var(--hillchart-label-font-size, 12px)');
    rightLabel.setAttribute('font-weight', 'var(--hillchart-label-font-weight, 600)');
    rightLabel.setAttribute('fill', 'var(--hillchart-label-color, #6b7280)');
    rightLabel.textContent = 'MAKING IT HAPPEN';
    this.svg.appendChild(rightLabel);
  }

  createControls() {
    if (!this.editable) return;
    
    const controls = document.createElement('div');
    controls.className = 'hillchart-controls';
    controls.style.cssText = 'margin-top: var(--hillchart-controls-spacing, 12px); display: flex; gap: var(--hillchart-controls-gap, 8px);';
    
    const updateBtn = document.createElement('button');
    updateBtn.textContent = 'Update';
    updateBtn.className = 'hillchart-btn hillchart-btn-secondary';
    updateBtn.style.cssText = 'padding: var(--hillchart-btn-padding, 6px 12px); font-size: var(--hillchart-btn-font-size, 14px); font-weight: 500; color: var(--hillchart-btn-color, #374151); background: var(--hillchart-btn-bg, #ffffff); border: 1px solid var(--hillchart-btn-border, #d1d5db); border-radius: var(--hillchart-btn-radius, 6px); cursor: pointer;';
    updateBtn.onclick = () => this.setMode('edit');
    
    const saveBtn = document.createElement('button');
    saveBtn.textContent = 'Save';
    saveBtn.className = 'hillchart-btn hillchart-btn-primary';
    saveBtn.style.cssText = 'padding: var(--hillchart-btn-padding, 6px 12px); font-size: var(--hillchart-btn-font-size, 14px); font-weight: 500; color: var(--hillchart-btn-primary-color, #ffffff); background: var(--hillchart-btn-primary-bg, #2563eb); border: 1px solid var(--hillchart-btn-primary-border, #2563eb); border-radius: var(--hillchart-btn-radius, 6px); cursor: pointer; display: none;';
    saveBtn.onclick = () => this.save();
    
    const cancelBtn = document.createElement('button');
    cancelBtn.textContent = 'Cancel';
    cancelBtn.className = 'hillchart-btn hillchart-btn-secondary';
    cancelBtn.style.cssText = 'padding: var(--hillchart-btn-padding, 6px 12px); font-size: var(--hillchart-btn-font-size, 14px); font-weight: 500; color: var(--hillchart-btn-color, #374151); background: var(--hillchart-btn-bg, #ffffff); border: 1px solid var(--hillchart-btn-border, #d1d5db); border-radius: var(--hillchart-btn-radius, 6px); cursor: pointer; display: none;';
    cancelBtn.onclick = () => this.cancel();
    
    // Add hover styles
    [updateBtn, cancelBtn].forEach(btn => {
      btn.addEventListener('mouseenter', () => {
        btn.style.background = 'var(--hillchart-btn-hover-bg, #f9fafb)';
      });
      btn.addEventListener('mouseleave', () => {
        btn.style.background = 'var(--hillchart-btn-bg, #ffffff)';
      });
    });
    
    saveBtn.addEventListener('mouseenter', () => {
      saveBtn.style.background = 'var(--hillchart-btn-primary-hover-bg, #1d4ed8)';
    });
    saveBtn.addEventListener('mouseleave', () => {
      saveBtn.style.background = 'var(--hillchart-btn-primary-bg, #2563eb)';
    });
    
    controls.appendChild(updateBtn);
    controls.appendChild(saveBtn);
    controls.appendChild(cancelBtn);
    
    this.element.appendChild(controls);
    this.controls = { controls, updateBtn, saveBtn, cancelBtn };
  }

  setMode(mode) {
    this.mode = mode;
    if (this.editable && this.controls) {
      if (mode === 'edit') {
        this.controls.updateBtn.style.display = 'none';
        this.controls.saveBtn.style.display = 'inline-block';
        this.controls.cancelBtn.style.display = 'inline-block';
        // Reset dirty tracking and save original positions when entering edit mode
        this.dirtyDots.clear();
        this.originalPositions.clear();
        this.dots.forEach(dot => {
          this.originalPositions.set(dot.id, dot.position);
        });
      } else {
        this.controls.updateBtn.style.display = 'inline-block';
        this.controls.saveBtn.style.display = 'none';
        this.controls.cancelBtn.style.display = 'none';
      }
      
      this.render(); // Re-render to apply drag handlers
    }
  }

  getYForX(x, marginRatio, sigma) {
    // If parameters not provided, get them from CSS (for backward compatibility)
    if (marginRatio === undefined || sigma === undefined) {
      const computedStyle = getComputedStyle(document.documentElement);
      marginRatio = parseFloat(computedStyle.getPropertyValue('--hillchart-margin-ratio') || '0.15');
      sigma = parseFloat(computedStyle.getPropertyValue('--hillchart-gaussian-sigma') || '0.3');
    }
    
    const margin = this.height * marginRatio;
    const baseY = this.height - margin;
    const peakY = margin;
    const t = x / this.width;
    // Gaussian-like bell curve
    const gaussian = Math.exp(-0.5 * Math.pow((t - 0.5) / sigma, 2));
    return baseY - (baseY - peakY) * gaussian;
  }

  render() {
    const dots = this.svg.querySelectorAll('.hill-dot, .debug-text');
    dots.forEach(dot => dot.remove());
    
    // Cache CSS values outside the loop
    const computedStyle = getComputedStyle(document.documentElement);
    const defaultSize = computedStyle.getPropertyValue('--hillchart-dot-default-size') || '6';
    const defaultColor = computedStyle.getPropertyValue('--hillchart-dot-default-color') || '#007bff';
    const minWidth = parseFloat(computedStyle.getPropertyValue('--hillchart-text-min-width') || '60');
    const charWidth = parseFloat(computedStyle.getPropertyValue('--hillchart-text-char-width') || '7');
    const textPadding = parseFloat(computedStyle.getPropertyValue('--hillchart-text-padding') || '10');
    
    this.dots.forEach(dotData => {
      const dot = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
      const x = (dotData.position / 100) * this.width;
      const y = this.getYForX(x);
      
      dot.setAttribute('cx', x);
      dot.setAttribute('cy', y);
      dot.setAttribute('r', dotData.size || defaultSize);
      dot.setAttribute('fill', dotData.color || defaultColor);
      dot.setAttribute('stroke', 'var(--hillchart-dot-stroke, #ffffff)');
      dot.setAttribute('stroke-width', 'var(--hillchart-dot-stroke-width, 2px)');
      dot.classList.add('hill-dot');
      dot.dataset.id = dotData.id;
      
      // Add description text with background
      const description = dotData.description || dotData.id;
      const truncated = description.length > this.truncateLength ? description.substring(0, this.truncateLength) + '...' : description;
      const textWidth = Math.max(minWidth, truncated.length * charWidth + textPadding);
      
      // Smart positioning: left side if text would go beyond right edge
      const onLeft = (x + 12 + textWidth) > this.width;
      const bgX = onLeft ? x - textWidth - 12 : x + 12;
      const textX = onLeft ? x - textWidth - 9 : x + 15;
      
      const textBg = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
      textBg.setAttribute('x', bgX);
      textBg.setAttribute('y', y - 8);
      textBg.setAttribute('width', textWidth);
      textBg.setAttribute('height', '16');
      textBg.setAttribute('fill', 'var(--hillchart-text-bg, #ffffff)');
      textBg.setAttribute('stroke', 'var(--hillchart-text-border, #d1d5db)');
      textBg.setAttribute('stroke-width', 'var(--hillchart-text-border-width, 1px)');
      textBg.setAttribute('rx', parseFloat(computedStyle.getPropertyValue('--hillchart-text-border-radius') || '3'));
      textBg.classList.add('debug-text');
      textBg.dataset.id = dotData.id;
      
      const text = document.createElementNS('http://www.w3.org/2000/svg', 'text');
      text.setAttribute('x', textX);
      text.setAttribute('y', y + 3);
      text.setAttribute('font-size', 'var(--hillchart-text-font-size, 11px)');
      text.setAttribute('font-family', 'var(--hillchart-text-font-family, sans-serif)');
      text.setAttribute('fill', 'var(--hillchart-text-color, #374151)');
      text.classList.add('debug-text');
      text.dataset.id = dotData.id;
      text.textContent = truncated;
      
      if (this.editable && this.mode === 'edit') {
        dot.style.cursor = 'grab';
        this.makeDraggable(dot, dotData);
      }
      
      this.svg.appendChild(dot);
      this.svg.appendChild(textBg);
      this.svg.appendChild(text);
    });
  }

  setupGlobalDragHandlers() {
    this.mouseMoveHandler = (e) => {
      if (!this.currentDrag) return;
      
      const { dot, dotData, cachedStyles, cachedTextElements, cachedRect, cachedTextData } = this.currentDrag;
      
      const x = Math.max(0, Math.min(this.width, e.clientX - cachedRect.left));
      const y = this.getYForX(x);
      
      dot.setAttribute('cx', x);
      dot.setAttribute('cy', y);
      
      // Smart positioning: left side if text would go beyond right edge
      const onLeft = (x + 12 + cachedTextData.textWidth) > this.width;
      const bgX = onLeft ? x - cachedTextData.textWidth - 12 : x + 12;
      const textX = onLeft ? x - cachedTextData.textWidth - 9 : x + 15;
      
      cachedTextElements.forEach((el, i) => {
        if (el.tagName === 'rect') {
          el.setAttribute('x', bgX);
          el.setAttribute('y', y - 8);
          el.setAttribute('width', cachedTextData.textWidth);
        } else {
          el.setAttribute('x', textX);
          el.setAttribute('y', y + 3);
          el.textContent = cachedTextData.truncated;
        }
      });
      
      dotData.position = (x / this.width) * 100;
      this.dirtyDots.add(dotData.id);
    };
    
    this.mouseUpHandler = () => {
      if (this.currentDrag) {
        this.currentDrag.dot.style.cursor = 'grab';
        this.currentDrag = null;
      }
    };
    
    // mousemove must be on document to track outside element boundaries
    document.addEventListener('mousemove', this.mouseMoveHandler);
    // mouseup can be on document for consistency
    document.addEventListener('mouseup', this.mouseUpHandler);
    
    // Auto-cleanup when element is removed from DOM
    this.observer = new MutationObserver(() => {
      if (!document.contains(this.element)) {
        this.destroy();
      }
    });
    this.observer.observe(document.body, { childList: true, subtree: true });
  }

  makeDraggable(dot, dotData) {
    dot.addEventListener('mousedown', (e) => {
      dot.style.cursor = 'grabbing';
      e.preventDefault();
      
      // Cache CSS values, text elements, bounding rect, and static text data once when drag starts
      const computedStyle = getComputedStyle(document.documentElement);
      const cachedStyles = {
        minWidth: parseFloat(computedStyle.getPropertyValue('--hillchart-text-min-width') || '60'),
        charWidth: parseFloat(computedStyle.getPropertyValue('--hillchart-text-char-width') || '7'),
        textPadding: parseFloat(computedStyle.getPropertyValue('--hillchart-text-padding') || '10')
      };
      const cachedTextElements = this.svg.querySelectorAll(`.debug-text[data-id="${dotData.id}"]`);
      const cachedRect = this.svg.getBoundingClientRect();
      
      const description = dotData.description || dotData.id;
      const truncated = description.length > this.truncateLength ? description.substring(0, this.truncateLength) + '...' : description;
      const textWidth = Math.max(cachedStyles.minWidth, truncated.length * cachedStyles.charWidth + cachedStyles.textPadding);
      const cachedTextData = { description, truncated, textWidth };
      
      this.currentDrag = { dot, dotData, cachedStyles, cachedTextElements, cachedRect, cachedTextData };
    });
  }

  save() {
    this.setMode('view');
    this.render();
    
    // Create positions array with original and new values for changed dots
    const changedPositions = [];
    this.dirtyDots.forEach(dotId => {
      const dot = this.dots.find(d => d.id === dotId);
      if (dot && this.originalPositions.has(dotId)) {
        changedPositions.push({
          id: dotId,
          original: this.originalPositions.get(dotId),
          new: dot.position
        });
      }
    });
    
    this.element.dispatchEvent(new CustomEvent('hillchart:save', { 
      detail: { 
        positions: changedPositions,
        allDots: this.dots
      } 
    }));
    
    // Clear dirty tracking after save
    this.dirtyDots.clear();
  }

  cancel() {
    // Restore original positions for dirty dots
    this.dirtyDots.forEach(dotId => {
      const dot = this.dots.find(d => d.id === dotId);
      if (dot && this.originalPositions.has(dotId)) {
        dot.position = this.originalPositions.get(dotId);
      }
    });
    
    // Clear tracking
    this.dirtyDots.clear();
    this.originalPositions.clear();
    
    this.setMode('view');
    this.render();
  }

  updateDots(dots) {
    this.dots = dots;
    this.render();
  }

  destroy() {
    // Clean up global event listeners
    if (this.mouseMoveHandler) {
      document.removeEventListener('mousemove', this.mouseMoveHandler);
    }
    if (this.mouseUpHandler) {
      document.removeEventListener('mouseup', this.mouseUpHandler);
    }
    
    // Clean up mutation observer
    if (this.observer) {
      this.observer.disconnect();
    }
    
    // Clear current drag state
    this.currentDrag = null;
    
    // Clear element content
    this.element.innerHTML = '';
  }
}

export { HillChart };
