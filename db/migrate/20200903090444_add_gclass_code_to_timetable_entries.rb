class AddGclassCodeToTimetableEntries < ActiveRecord::Migration
  def self.up
    add_column :timetable_entries, :gclass_code, :string
  end

  def self.down
    remove_column :timetable_entries, :gclass_code
  end
end
