RSpec::Matchers.define :exit_with_code do |expected_code|
  actual_code = nil
  
  match do |block|
    begin
      block.call
      actual_code = 0
    rescue SystemExit => e
      actual_code = e.status
    end
    
    actual_code == expected_code
  end
  
  failure_message do |block|
    "expected block to exit with code #{expected_code}, but exited with code #{actual_code}"
  end
  
  failure_message_when_negated do |block|
    "expected block not to exit with code #{expected_code}, but it did"
  end
  
  supports_block_expectations
end