class AddTrialExpiresAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :trial_expires_at, :datetime
  end
end
