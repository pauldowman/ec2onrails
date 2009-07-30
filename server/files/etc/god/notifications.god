God::Contacts::Email.message_settings = {
  :from => 'root@localhost'
}

God::Contacts::Email.delivery_method = :sendmail

God.contact(:email) do |c|
  c.name = 'root'
  c.email = 'root@localhost'
  c.group = 'default'
end
