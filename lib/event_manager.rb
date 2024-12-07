require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

# Data Cleaning Methods
def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, "0")[0..4]
end

def clean_phonenumber(phone)
  phone = phone.to_s.gsub(/[^\d]/, '')

  case phone.length
  when 10
    phone
  when 11
    phone.start_with?('1') ? phone[1..-1] : "0000000000"
  else
    "0000000000"
  end
end

# Time Analysis Methods
def get_registration_hour(regdate)
  Time.strptime(regdate, '%m/%d/%y %H:%M').hour
end

def get_registration_day(regdate)
  Time.strptime(regdate, '%m/%d/%y %H:%M').wday
end

# Display Methods
def display_peak_hours(hour_counts)
  puts "\nPeak Registration Hours:"
  sorted_hours = hour_counts.sort_by { |hour, count| -count }
  sorted_hours.each do |hour, count|
    am_pm = hour >= 12 ? 'PM' : 'AM'
    display_hour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
    puts "#{display_hour}:00 #{am_pm}: #{count} registrations"
  end
end

def display_peak_days(day_counts)
  puts "\nPeak Registration Days:"
  days = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]

  sorted_days = day_counts.sort_by { |day, count| -count }
  sorted_days.each do |day_number, count|
    puts "#{days[day_number]}: #{count} registrations"
  end
end

# Legislator Information Method
def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

# File Management Method
def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')
  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

# Main Program
puts 'EventManager initialized.'

# Initialize Counters
hour_counts = Hash.new(0)
day_counts = Hash.new(0)

# Read Input File
contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

# Load Letter Template
template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

# Process Each Registration
contents.each do |row|
  # Extract and clean data
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone_number = clean_phonenumber(row[:homephone])

  # Get legislator information
  legislators = legislators_by_zipcode(zipcode)

  # Track registration patterns
  registration_hour = get_registration_hour(row[:regdate])
  hour_counts[registration_hour] += 1

  registration_day = get_registration_day(row[:regdate])
  day_counts[registration_day] += 1

  # Generate and save thank you letter
  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)
end

# Display Analysis Results
display_peak_hours(hour_counts)
display_peak_days(day_counts)
