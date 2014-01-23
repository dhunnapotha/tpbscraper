#http://stackoverflow.com/questions/12884711/how-to-send-email-via-smtp-with-rubys-mail-gem
require 'mail'

options = { :address              => "smtp.gmail.com",
            :port                 => 587,
            :domain               => ENV['GC_GMAIL_DOMAIN'],
            :user_name            => ENV['GC_GMAIL_USERNAME'],


            :password             => ENV['GC_GMAIL_PASSWORD'],
            :authentication       => 'plain',
            :enable_starttls_auto => true  }



Mail.defaults do
  delivery_method :smtp, options
end

def send_mail_from_gmail_smtp(from,to,subject,body)
  Mail.deliver do
    to to
    from from
    subject subject
    body body
    charset = "UTF-8"
  end
end
