class EnableUuidExtension < ActiveRecord::Migration[8.0]
  def change
    # Enable the pgcrypto extension for UUID generation
    enable_extension 'pgcrypto'
  end
end
