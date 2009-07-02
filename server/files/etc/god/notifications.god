God::Contacts::Email.message_settings = {
  :from => 'root@localhost'
}

God::Contacts::Email.server_settings = {
   :address => 'localhost',
   :port => 25
}

God.contact(:email) do |c|
  c.name = 'app'
  c.email = 'root@localhost'
  c.group = 'default'
end
