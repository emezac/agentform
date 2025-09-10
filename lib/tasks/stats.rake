# lib/tasks/stats.rake

namespace :stats do
  desc "Resets and updates all counter cache columns for forms"
  task reset_form_counters: :environment do
    puts "Recalculating form counters..."
    Form.find_each do |form|
      Form.reset_counters(form.id, :form_responses)
    end
    puts "✅ Done. All form counters have been updated."
  end
end