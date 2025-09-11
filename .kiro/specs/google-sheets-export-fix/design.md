# Design Document

## Overview

The Google Sheets export functionality is failing to export actual response data, only exporting headers. Based on the code analysis, the issue appears to be in the data formatting and retrieval process within the `Integrations::GoogleSheetsService`. The job is being enqueued correctly, but the response data is not being properly formatted or retrieved when building the spreadsheet rows.

## Architecture

### Current Problem Analysis

The issue occurs in the export pipeline:

1. **Job Enqueuing**: ✅ Working correctly - `GoogleSheetsSyncJob` is being enqueued
2. **Service Initialization**: ✅ Working correctly - `GoogleSheetsService` is initialized
3. **Response Retrieval**: ⚠️ Potential issue - responses are being found but data may not be loaded correctly
4. **Data Formatting**: ❌ **Primary Issue** - `format_answer_value` method is not correctly extracting data from `QuestionResponse`
5. **Spreadsheet Writing**: ✅ Working correctly - rows are being written to Google Sheets

### Root Cause Analysis

The main issue is in the `format_answer_value` method in `GoogleSheetsService`. The method calls `answer.formatted_answer` but this may be returning empty values due to:

1. **Data Loading Issues**: Question responses may not be properly loaded with their associations
2. **Answer Data Structure**: The `answer_data` field structure may not match what `formatted_answer` expects
3. **Question Type Handling**: Different question types may require different formatting approaches
4. **Null/Empty Data Handling**: Empty or null responses may not be handled correctly

## Components and Interfaces

### 1. Enhanced Data Loading

Modify the response loading to ensure all necessary associations are included:

```ruby
# In GoogleSheetsService#export_all_responses
responses = @form.form_responses
  .includes(:question_responses => :form_question)
  .where(status: ['completed', 'partial'])
  .order(created_at: :desc)
```

### 2. Improved Answer Formatting

Create a more robust answer formatting method:

```ruby
def format_answer_value(answer, question)
  return '' unless answer.present?
  
  # Log for debugging
  Rails.logger.debug "Formatting answer for question #{question.id} (#{question.question_type})"
  Rails.logger.debug "Answer data: #{answer.answer_data.inspect}"
  
  # Handle different data structures
  formatted_value = case answer.answer_data
  when Hash
    # Use the formatted_answer method if available
    if answer.respond_to?(:formatted_answer)
      answer.formatted_answer
    else
      # Fallback to direct value extraction
      answer.answer_data['value'] || answer.answer_data.values.first
    end
  when String, Numeric
    answer.answer_data
  when Array
    answer.answer_data.join(', ')
  else
    answer.answer_data.to_s
  end
  
  # Ensure we return a string
  formatted_value.to_s.strip
end
```

### 3. Enhanced Logging and Debugging

Add comprehensive logging throughout the export process:

```ruby
def build_response_row(response)
  Rails.logger.info "Building row for response #{response.id}"
  Rails.logger.debug "Response status: #{response.status}"
  Rails.logger.debug "Response has #{response.question_responses.count} question responses"
  
  row = [
    response.created_at.strftime('%Y-%m-%d %H:%M:%S'),
    response.id
  ]

  @form.form_questions.order(:position).each do |question|
    answer = response.question_responses.find { |qr| qr.form_question_id == question.id }
    
    Rails.logger.debug "Question '#{question.title}' (#{question.question_type}): #{answer ? 'found' : 'not found'}"
    
    if answer
      Rails.logger.debug "Answer data: #{answer.answer_data.inspect}"
      formatted_value = format_answer_value(answer, question)
      Rails.logger.debug "Formatted value: #{formatted_value.inspect}"
    else
      formatted_value = ''
    end
    
    row << formatted_value
  end

  Rails.logger.info "Built row with #{row.length} columns: #{row.inspect}"
  row
end
```

### 4. Data Validation and Error Handling

Add validation to ensure data integrity:

```ruby
def export_all_responses
  return self.class.failure("No integration configured") unless @integration&.can_sync?

  begin
    Rails.logger.info "Starting export for form #{@form.id} (#{@form.name})"
    
    # Validate form has questions
    if @form.form_questions.empty?
      return self.class.failure("Form has no questions to export")
    end
    
    # Load responses with proper associations
    responses = load_responses_for_export
    Rails.logger.info "Found #{responses.count} responses to export"
    
    # Validate responses have data
    responses_with_data = responses.select { |r| r.question_responses.any? }
    Rails.logger.info "#{responses_with_data.count} responses have answer data"
    
    if responses_with_data.empty?
      Rails.logger.warn "No responses with data found"
      return self.class.success("No responses with data to export")
    end
    
    # Clear and rebuild data
    clear_data_rows
    rows = build_response_rows(responses_with_data)
    
    Rails.logger.info "Built #{rows.size} data rows"
    rows.each_with_index do |row, index|
      Rails.logger.debug "Row #{index + 1}: #{row.inspect}"
    end
    
    append_rows(rows) if rows.any?
    
    @integration.mark_sync_success!
    self.class.success("Exported #{responses_with_data.count} responses successfully")
    
  rescue => e
    Rails.logger.error "Export failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    @integration.mark_sync_error!(e)
    self.class.failure("Export failed: #{e.message}")
  end
end

private

def load_responses_for_export
  @form.form_responses
    .includes(question_responses: :form_question)
    .where(status: ['completed', 'partial'])
    .order(created_at: :desc)
end
```

## Data Models

No changes to data models are required, but we need to ensure proper data loading and association handling.

## Error Handling

### Enhanced Error Reporting

1. **Detailed Logging**: Add comprehensive logging at each step of the export process
2. **Data Validation**: Validate that responses contain actual data before attempting export
3. **Graceful Degradation**: Handle missing or malformed data without breaking the entire export
4. **User Feedback**: Provide clear feedback about export status and any issues

### Error Recovery

```ruby
def format_answer_value_with_fallback(answer, question)
  return '' unless answer.present?
  
  begin
    # Primary method: use formatted_answer
    if answer.respond_to?(:formatted_answer)
      result = answer.formatted_answer
      return result.to_s if result.present?
    end
    
    # Fallback 1: direct answer_data access
    if answer.answer_data.present?
      case answer.answer_data
      when Hash
        return answer.answer_data['value']&.to_s || answer.answer_data.values.first&.to_s || ''
      when Array
        return answer.answer_data.join(', ')
      else
        return answer.answer_data.to_s
      end
    end
    
    # Fallback 2: empty string
    return ''
    
  rescue => e
    Rails.logger.error "Error formatting answer for question #{question.id}: #{e.message}"
    return "[Error: #{e.message}]"
  end
end
```

## Testing Strategy

### Unit Tests

1. Test `format_answer_value` with different question types and data structures
2. Test `build_response_row` with various response scenarios
3. Test error handling and fallback mechanisms

### Integration Tests

1. Test full export process with real form data
2. Test export with different question types (text, multiple choice, file uploads, etc.)
3. Test export with empty/partial responses

### Production Debugging

1. Add temporary enhanced logging to production
2. Create diagnostic rake task to test export functionality
3. Monitor export success/failure rates

## Performance Considerations

### Optimizations

1. **Batch Processing**: Process responses in batches for large datasets
2. **Efficient Loading**: Use includes to avoid N+1 queries
3. **Memory Management**: Process large exports in chunks to avoid memory issues

### Monitoring

1. **Export Metrics**: Track export duration and success rates
2. **Data Volume**: Monitor the amount of data being exported
3. **Error Rates**: Track and alert on export failures

## Deployment Strategy

### Phase 1: Enhanced Logging and Debugging

1. Deploy enhanced logging to identify the exact issue
2. Add diagnostic tools to test export functionality
3. Monitor logs to confirm the root cause

### Phase 2: Fix Implementation

1. Implement improved data loading and formatting
2. Add robust error handling and fallbacks
3. Deploy with comprehensive testing

### Phase 3: Monitoring and Optimization

1. Monitor export success rates
2. Optimize performance based on usage patterns
3. Add user-facing export status indicators

## Rollback Plan

If issues arise:

1. **Immediate**: Disable auto-sync to prevent failed exports
2. **Temporary**: Provide manual CSV export as alternative
3. **Recovery**: Revert to previous version while investigating
4. **Communication**: Notify users of temporary export issues and expected resolution time