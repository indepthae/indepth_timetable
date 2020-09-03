# Include hook code here
require 'dispatcher'
require 'translator'
require File.join(File.dirname(__FILE__), "lib", "indepth_timetable")
require File.join(File.dirname(__FILE__), "config", "breadcrumbs")
FedenaPlugin.register = {
    :name=>"indepth_timetable",
    :description=>"Indepth Timetable",
    :no_select => true
}

Dir[File.join("#{File.dirname(__FILE__)}/config/locales/*.yml")].each do |locale|
  I18n.load_path.unshift(locale)
end

IndepthTimetable.attach_overrides


if RAILS_ENV == 'development'
  ActiveSupport::Dependencies.load_once_paths.\
    reject!{|x| x =~ /^#{Regexp.escape(File.dirname(__FILE__))}/}
end

Authorization::AUTH_DSL_FILES << "#{RAILS_ROOT}/vendor/plugins/indepth_timetable/config/indepth_timetable_auth.rb"


