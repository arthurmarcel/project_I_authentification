class CreateApplications < ActiveRecord::Migration
	def up
		create_table :applications do |tbl|
			tbl.string :name
			tbl.string :url
			tbl.integer :user_id
		end
	end

	def down
		drop_table :applications
	end
end
