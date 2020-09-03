class AddMeetingPasscodeToTimetableEntries < ActiveRecord::Migration
  def self.up
    add_column :timetable_entries, :meeting_passcode, :string
  end

  def self.down
    remove_column :timetable_entries, :meeting_passcode
  end
end
