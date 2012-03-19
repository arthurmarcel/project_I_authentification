class CreateUses < ActiveRecord::Migration
	def up
		create_table :uses do |tbl|
			tbl.integer :user_id
			tbl.integer :application_id
		end
	end

	def down
		drop_table :uses
	end
end
