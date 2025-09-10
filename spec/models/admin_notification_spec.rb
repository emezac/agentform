require 'rails_helper'

RSpec.describe AdminNotification, type: :model do
  let(:user) { create(:user) }
  
  describe 'validations' do
    it 'validates presence of event_type' do
      notification = build(:admin_notification, event_type: nil)
      expect(notification).not_to be_valid
      expect(notification.errors[:event_type]).to include("can't be blank")
    end

    it 'validates presence of title' do
      notification = build(:admin_notification, title: nil)
      expect(notification).not_to be_valid
      expect(notification.errors[:title]).to include("can't be blank")
    end

    it 'validates event_type inclusion' do
      notification = build(:admin_notification, event_type: 'invalid_type')
      expect(notification).not_to be_valid
      expect(notification.errors[:event_type]).to include("is not included in the list")
    end

    it 'validates priority inclusion' do
      notification = build(:admin_notification, priority: 'invalid_priority')
      expect(notification).not_to be_valid
      expect(notification.errors[:priority]).to include("is not included in the list")
    end
  end

  describe 'associations' do
    it 'belongs to user optionally' do
      notification = create(:admin_notification, user: nil)
      expect(notification.user).to be_nil
      expect(notification).to be_valid
    end

    it 'can belong to a user' do
      notification = create(:admin_notification, user: user)
      expect(notification.user).to eq(user)
    end
  end

  describe 'scopes' do
    let!(:read_notification) { create(:admin_notification, read_at: 1.hour.ago) }
    let!(:unread_notification) { create(:admin_notification, read_at: nil) }
    let!(:high_priority) { create(:admin_notification, priority: 'high') }
    let!(:normal_priority) { create(:admin_notification, priority: 'normal') }

    describe '.unread' do
      it 'returns only unread notifications' do
        expect(AdminNotification.unread).to include(unread_notification)
        expect(AdminNotification.unread).not_to include(read_notification)
      end
    end

    describe '.read' do
      it 'returns only read notifications' do
        expect(AdminNotification.read).to include(read_notification)
        expect(AdminNotification.read).not_to include(unread_notification)
      end
    end

    describe '.by_priority' do
      it 'filters by priority' do
        expect(AdminNotification.by_priority('high')).to include(high_priority)
        expect(AdminNotification.by_priority('high')).not_to include(normal_priority)
      end
    end

    describe '.recent' do
      it 'orders by created_at desc' do
        older = create(:admin_notification, created_at: 2.hours.ago)
        newer = create(:admin_notification, created_at: 1.hour.ago)
        
        expect(AdminNotification.recent.first).to eq(newer)
        expect(AdminNotification.recent.last).to eq(older)
      end
    end
  end

  describe 'instance methods' do
    let(:notification) { create(:admin_notification) }

    describe '#read?' do
      it 'returns true when read_at is present' do
        notification.update!(read_at: Time.current)
        expect(notification.read?).to be true
      end

      it 'returns false when read_at is nil' do
        notification.update!(read_at: nil)
        expect(notification.read?).to be false
      end
    end

    describe '#unread?' do
      it 'returns false when read_at is present' do
        notification.update!(read_at: Time.current)
        expect(notification.unread?).to be false
      end

      it 'returns true when read_at is nil' do
        notification.update!(read_at: nil)
        expect(notification.unread?).to be true
      end
    end

    describe '#mark_as_read!' do
      it 'sets read_at to current time' do
        expect(notification.read_at).to be_nil
        notification.mark_as_read!
        expect(notification.read_at).to be_present
        expect(notification.read_at).to be_within(1.second).of(Time.current)
      end

      it 'does not update if already read' do
        original_time = 1.hour.ago
        notification.update!(read_at: original_time)
        
        notification.mark_as_read!
        expect(notification.read_at).to be_within(1.second).of(original_time)
      end
    end

    describe '#priority_color' do
      it 'returns correct color for critical priority' do
        notification.update!(priority: 'critical')
        expect(notification.priority_color).to eq('text-red-600 bg-red-50')
      end

      it 'returns correct color for high priority' do
        notification.update!(priority: 'high')
        expect(notification.priority_color).to eq('text-orange-600 bg-orange-50')
      end
    end

    describe '#event_icon' do
      it 'returns correct icon for user_registered event' do
        notification.update!(event_type: 'user_registered')
        expect(notification.event_icon).to eq('👋')
      end

      it 'returns correct icon for trial_expired event' do
        notification.update!(event_type: 'trial_expired')
        expect(notification.event_icon).to eq('⏰')
      end
    end
  end

  describe 'class methods' do
    describe '.notify_user_registered' do
      it 'creates a user registration notification' do
        expect {
          AdminNotification.notify_user_registered(user)
        }.to change(AdminNotification, :count).by(1)

        notification = AdminNotification.last
        expect(notification.event_type).to eq('user_registered')
        expect(notification.user).to eq(user)
        expect(notification.title).to eq('New user registered')
        expect(notification.priority).to eq('normal')
      end
    end

    describe '.notify_user_upgraded' do
      it 'creates a user upgrade notification' do
        expect {
          AdminNotification.notify_user_upgraded(user, 'basic', 'premium')
        }.to change(AdminNotification, :count).by(1)

        notification = AdminNotification.last
        expect(notification.event_type).to eq('user_upgraded')
        expect(notification.user).to eq(user)
        expect(notification.priority).to eq('high')
        expect(notification.metadata['from_plan']).to eq('basic')
        expect(notification.metadata['to_plan']).to eq('premium')
      end
    end

    describe '.notify_trial_expired' do
      it 'creates a trial expiration notification' do
        expect {
          AdminNotification.notify_trial_expired(user)
        }.to change(AdminNotification, :count).by(1)

        notification = AdminNotification.last
        expect(notification.event_type).to eq('trial_expired')
        expect(notification.user).to eq(user)
        expect(notification.priority).to eq('high')
      end
    end
  end
end
