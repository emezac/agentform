# app/channels/application_cable/connection.rb
module ApplicationCable
    class Connection < ActionCable::Connection::Base
      # Aquí puedes agregar autenticación si la necesitas
      # identified_by :current_user
      
      # def connect
      #   self.current_user = find_verified_user
      # end
      
      # private
      
      # def find_verified_user
      #   # Lógica de autenticación
      # end
    end
  end