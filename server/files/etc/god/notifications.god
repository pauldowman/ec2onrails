God::Contacts::Email.message_settings = {
  :from => 'root@localhost'
  # TODO add RAILS_ENV to subject
}

God::Contacts::Email.server_settings = {
   :address => 'localhost',
   :port => 25
}

God.contact(:email) do |c|
  c.name = 'root'
  c.email = 'root@localhost'
  c.group = 'default'
end
