import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="form-preview"
export default class extends Controller {
  static targets = ["wordCount", "costEstimate", "contentInput", "promptInput", "previewArea", "feedback"]
  static values = { 
    baseCost: { type: Number, default: 0.05 },
    questionCost: { type: Number, default: 0.01 },
    minWords: { type: Number, default: 10 },
    maxWords: { type: Number, default: 5000 },
    wordsPerQuestion: { type: Number, default: 50 } // Rough estimate for question generation
  }

  connect() {
    this.updatePreview()
    this.setupDebouncing()
  }

  setupDebouncing() {
    this.debounceTimer = null
    this.debounceDelay = 300 // 300ms delay
  }

  updatePreview(event) {
    // Clear existing timer
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    // Set new timer for debounced update
    this.debounceTimer = setTimeout(() => {
      this.performUpdate()
    }, this.debounceDelay)
  }

  performUpdate() {
    const content = this.getContentText()
    const wordCount = this.countWords(content)
    const estimatedQuestions = this.estimateQuestionCount(wordCount)
    const estimatedCost = this.calculateCost(estimatedQuestions)
    
    this.updateWordCount(wordCount)
    this.updateCostEstimate(estimatedCost, estimatedQuestions)
    this.updateFeedback(wordCount, content)
    
    // Dispatch update event for other controllers
    this.dispatch('updated', {
      detail: {
        wordCount: wordCount,
        estimatedCost: estimatedCost,
        estimatedQuestions: estimatedQuestions,
        isValid: this.isContentValid(wordCount)
      }
    })
  }

  getContentText() {
    if (this.hasPromptInputTarget) {
      return this.promptInputTarget.value.trim()
    } else if (this.hasContentInputTarget) {
      return this.contentInputTarget.value.trim()
    }
    return ''
  }

  countWords(text) {
    if (!text) return 0
    
    // Split by whitespace and filter out empty strings
    return text.split(/\s+/).filter(word => word.length > 0).length
  }

  estimateQuestionCount(wordCount) {
    if (wordCount === 0) return 0
    
    // Estimate questions based on content length
    // More sophisticated logic could be added here
    const baseQuestions = Math.max(1, Math.floor(wordCount / this.wordsPerQuestionValue))
    return Math.min(baseQuestions, 20) // Cap at 20 questions max
  }

  calculateCost(questionCount) {
    return this.baseCostValue + (questionCount * this.questionCostValue)
  }

  updateWordCount(count) {
    if (this.hasWordCountTarget) {
      this.wordCountTarget.textContent = count.toLocaleString()
      
      // Add visual feedback based on word count
      this.wordCountTarget.classList.remove('text-gray-600', 'text-amber-600', 'text-red-600', 'text-green-600')
      
      if (count === 0) {
        this.wordCountTarget.classList.add('text-gray-600')
      } else if (count < this.minWordsValue) {
        this.wordCountTarget.classList.add('text-amber-600')
      } else if (count > this.maxWordsValue) {
        this.wordCountTarget.classList.add('text-red-600')
      } else {
        this.wordCountTarget.classList.add('text-green-600')
      }
    }
  }

  updateCostEstimate(cost, questionCount) {
    if (this.hasCostEstimateTarget) {
      const formattedCost = cost.toFixed(2)
      this.costEstimateTarget.textContent = `$${formattedCost}`
      
      // Update additional cost information if available
      const costContainer = this.costEstimateTarget.closest('.cost-breakdown')
      if (costContainer) {
        const questionInfo = costContainer.querySelector('.question-estimate')
        if (questionInfo) {
          questionInfo.textContent = `~${questionCount} questions`
        }
      }
    }
  }

  updateFeedback(wordCount, content) {
    if (!this.hasFeedbackTarget) return

    let feedbackMessage = ''
    let feedbackClass = 'text-gray-600'

    if (wordCount === 0) {
      feedbackMessage = 'Start typing to see word count and cost estimate'
      feedbackClass = 'text-gray-600'
    } else if (wordCount < this.minWordsValue) {
      const needed = this.minWordsValue - wordCount
      feedbackMessage = `Add ${needed} more word${needed !== 1 ? 's' : ''} to meet minimum requirement`
      feedbackClass = 'text-amber-600'
    } else if (wordCount > this.maxWordsValue) {
      const excess = wordCount - this.maxWordsValue
      feedbackMessage = `Content is ${excess} word${excess !== 1 ? 's' : ''} over the limit. Please shorten.`
      feedbackClass = 'text-red-600'
    } else {
      feedbackMessage = 'Content length looks good!'
      feedbackClass = 'text-green-600'
    }

    this.feedbackTarget.textContent = feedbackMessage
    this.feedbackTarget.className = `text-sm ${feedbackClass}`
  }

  isContentValid(wordCount) {
    return wordCount >= this.minWordsValue && wordCount <= this.maxWordsValue
  }

  // Method to handle file content updates from file upload controller
  handleFileContent(event) {
    const { content } = event.detail
    if (this.hasContentInputTarget) {
      this.contentInputTarget.value = content
      this.updatePreview()
    }
  }

  // Method to clear preview
  clearPreview() {
    if (this.hasContentInputTarget) {
      this.contentInputTarget.value = ''
    }
    this.updatePreview()
  }

  // Method to get current metrics for external use
  getCurrentMetrics() {
    const content = this.getContentText()
    const wordCount = this.countWords(content)
    const estimatedQuestions = this.estimateQuestionCount(wordCount)
    const estimatedCost = this.calculateCost(estimatedQuestions)
    
    return {
      wordCount,
      estimatedQuestions,
      estimatedCost,
      isValid: this.isContentValid(wordCount),
      content
    }
  }

  // Method to update preview with external content
  setContent(content) {
    if (this.hasContentInputTarget) {
      this.contentInputTarget.value = content
      this.updatePreview()
    }
  }

  // Handle input events
  handleInput(event) {
    this.updatePreview()
  }

  // Handle paste events
  handlePaste(event) {
    // Small delay to allow paste content to be processed
    setTimeout(() => {
      this.updatePreview()
    }, 10)
  }

  // Method to use example prompts
  useExample(event) {
    const examplePrompt = event.currentTarget.dataset.examplePrompt
    if (examplePrompt && this.hasPromptInputTarget) {
      this.promptInputTarget.value = examplePrompt
      this.updatePreview()
      
      // Scroll to the prompt input
      this.promptInputTarget.scrollIntoView({ behavior: 'smooth', block: 'center' })
      
      // Focus the input for immediate editing
      this.promptInputTarget.focus()
      
      // Dispatch event to notify other controllers
      this.dispatch('exampleUsed', {
        detail: { prompt: examplePrompt }
      })
    }
  }

  disconnect() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
  }
}