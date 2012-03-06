class CreateUsers < ActiveRecord::Migration
	def up
		create_table :users do |tbl|
			tbl.string :login
			tbl.string :password
		end
	end

	def down
		drop_table :users
	end
end
