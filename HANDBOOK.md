# AgentForm Operating Handbook 📚

## Your Step-by-Step Guide to Creating Intelligent Forms

Welcome to AgentForm! This handbook will walk you through the complete process of creating and managing AI-powered forms. We'll start from scratch and build up to advanced features.

---

## 🎯 Quick Start Path

**Recommended Order:**
1. **Create your first basic form** (5 minutes)
2. **Add questions and configure settings** (10 minutes)  
3. **Enable AI features** (5 minutes)
4. **Test and publish** (5 minutes)
5. **Analyze responses** (ongoing)

---

## 📋 Part 1: Creating Your First Form

### Step 1: Access the Dashboard
1. Navigate to `http://localhost:3000`
2. Sign up for a new account or log in
3. Click **"Create New Agent"** (this creates a new form)

### Step 2: Basic Form Setup
**What you'll see:**
- **Form Name**: Enter "Customer Feedback Survey" 
- **Description**: "Help us improve our service quality"
- **Category**: Select "customer_feedback" from dropdown
- **Status**: Leave as "draft" for now

**Click "Create Form"**

### Step 3: Your First Questions
You'll land in the **Form Builder** with a blank canvas.

**Add your first question:**
1. Click **"Add Question"** button
2. Select **"Short Text"** from the question types
3. Enter:
   - **Title**: "What's your name?"
   - **Description**: "We'd like to address you personally"
   - **Required**: ✅ Check this box

**Add second question:**
1. Click **"Add Question"** again
2. Select **"Rating Scale"**
3. Enter:
   - **Title**: "How satisfied are you with our service?"
   - **Scale**: 1-5 stars
   - **Required**: ✅ Check this box

---

## 🤖 Part 2: Enabling AI Features

### Step 1: Turn on AI Enhancement
1. In the form builder, click **"Form Settings"** (top right)
2. Toggle **"AI Enhanced"** to ON
3. Select AI Model: **GPT-4o-mini** (recommended for beginners)
4. Click **"Save Settings"**

### Step 2: AI Question Enhancement
**Enhance your existing questions:**
1. Hover over "What's your name?" question
2. Click the **AI magic wand icon** ✨
3. The AI will suggest improvements like:
   - Better phrasing: "May I have your full name so we can personalize your experience?"
   - Add validation rules
   - Improve description

**Accept the suggestions** by clicking **"Apply Changes"**

### Step 3: Enable Dynamic Follow-ups
1. Go back to your rating scale question
2. Click **"Configure AI"**
3. Enable **"Dynamic Follow-up Questions"**
4. Set trigger: "If rating ≤ 3, ask for improvement suggestions"

---

## 🎨 Part 3: Advanced Question Types

### Adding Conditional Logic
**Scenario**: Only ask for improvement if satisfaction is low

1. Add a new **"Long Text"** question
2. Title: "What could we improve?"
3. In **"Conditional Logic"** tab:
   - **Show when**: Previous rating ≤ 3
   - **Hide when**: Previous rating > 3

### File Upload Question
1. Add **"File Upload"** question
2. Configure:
   - Title: "Upload a screenshot if relevant"
   - File types: Images only (.jpg, .png)
   - Max size: 5MB

### Matrix Questions
1. Add **"Matrix/Rating Scale"**
2. Use for: "Rate these aspects of our service"
   - Speed
   - Quality
   - Support
   - Value

---

## 🔍 Part 4: Testing Your Form

### Step 1: Preview Mode
1. Click **"Preview"** button (eye icon)
2. Test different scenarios:
   - Enter a low rating (should show improvement question)
   - Enter a high rating (should skip improvement question)
   - Try to submit without required fields

### Step 2: AI Testing
1. Return to builder
2. Click **"AI Test"** button
3. The AI will:
   - Check for logical flow
   - Suggest better question ordering
   - Identify potential user confusion points

---

## 🚀 Part 5: Publishing & Sharing

### Step 1: Publish Your Form
1. Click **"Save & Publish"**
2. Your form gets a unique URL: `yoursite.com/f/abc123`
3. **Copy the share link**

### Step 2: Multiple Sharing Options
**Direct link**: Share the generated URL
**Embed code**:
```html
<iframe src="yoursite.com/f/abc123" width="100%" height="600"></iframe>
```

**QR Code**: Generated automatically for print materials

---

## 📊 Part 6: Monitoring Responses

### Real-time Dashboard
After publishing, access your **Analytics Dashboard**:

**Key metrics to watch:**
- **Response Rate**: How many people complete the form
- **Drop-off Points**: Where people abandon the form
- **Completion Time**: Average time to complete

### AI Insights
**Sentiment Analysis**:
- Positive responses highlighted in green
- Negative responses in red
- Common themes automatically extracted

**Example insight**: "34% of low ratings mention 'slow response time'"

---

## 🎯 Part 7: Common Workflows

### Workflow 1: Lead Generation Form
**Goal**: Qualify potential customers

**Setup**:
1. Form type: Lead Generation
2. AI enabled: ✅
3. Lead scoring: Automatic
4. Questions:
   - Company size (dropdown)
   - Budget range (dropdown)
   - Timeline (radio buttons)
   - Specific needs (long text)

**AI Configuration**:
- Score high: Large companies + high budget + immediate timeline
- Auto-tag: "Hot lead", "Warm lead", "Cold lead"

### Workflow 2: Event Registration
**Goal**: Collect registrations with automatic confirmation

**Setup**:
1. Form type: Event Registration
2. Add fields:
   - Name
   - Email (with validation)
   - Dietary restrictions
   - Session preferences
3. Enable confirmation emails
4. Set capacity limits

### Workflow 3: Product Feedback
**Goal**: Collect structured product feedback

**Setup**:
1. Use **Net Promoter Score (NPS)** question type
2. Add conditional logic for detractors (score 0-6)
3. Enable AI analysis for common themes
4. Set up daily reports to product team

---

## 🛠️ Part 8: Troubleshooting Common Issues

### Issue: Form not showing
**Check**:
- Form status is "published" not "draft"
- Share link is correct
- No conflicting conditional logic

### Issue: AI features not working
**Check**:
- OpenAI API key configured in `.env`
- AI enhancement toggled ON in form settings
- Questions have enough context for AI to work with

### Issue: Low completion rates
**Solutions**:
- Reduce number of questions
- Add progress indicator
- Use conditional logic to skip irrelevant questions
- Enable auto-save so users don't lose progress

---

## 🎓 Part 9: Advanced Features (Next Steps)

### Custom Branding
1. Settings → Branding
2. Upload logo
3. Set brand colors
4. Custom CSS for advanced styling

### API Integration
```bash
# Create form via API
curl -X POST https://api.yoursite.com/v1/forms \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"form": {"name": "API Form", "ai_enabled": true}}'
```

### Webhooks
Set up webhooks to receive notifications:
- New response submitted
- Form completed
- AI identifies high-priority lead

---

## 📋 Quick Reference Card

### Keyboard Shortcuts
- **Ctrl+S**: Save form
- **Ctrl+P**: Preview
- **Ctrl+E**: Toggle AI enhancement
- **Escape**: Close modals

### Best Practices
1. **Start simple**: 3-5 questions max for first form
2. **Test thoroughly**: Always preview before publishing
3. **Use AI sparingly**: Enable for key questions, not all
4. **Monitor analytics**: Check dashboard weekly
5. **Iterate based on data**: Use insights to improve

### Support Resources
- **In-app help**: Click "?" icon in any section
- **Video tutorials**: Available in dashboard
- **Community**: Join Discord for questions
- **Email**: support@agentform.com

---

## 🏁 Your First Week Checklist

**Day 1**: Create and publish your first basic form
**Day 2**: Add AI enhancement to existing questions
**Day 3**: Set up conditional logic
**Day 4**: Review analytics and optimize
**Day 5**: Create a second form using lessons learned

**Success Metric**: 50%+ completion rate on your forms

---

*Welcome to the AgentForm community! Start with the basics, then gradually explore advanced features as you become comfortable.*