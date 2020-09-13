Gretel::Crumbs.layout do

crumb :timetable_special_sub_tt do
  link I18n.t('special_timetable_text'), {:controller => "timetable", :action => "special_sub_tt"}
  parent :timetable_student_view
end

crumb :timetable_special_sub_tt_employee do
  link I18n.t('special_timetable_text'), {:controller => "timetable", :action => "special_sub_tt_employee"}
  parent :timetable_student_view
end

end