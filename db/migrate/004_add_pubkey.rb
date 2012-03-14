class AddPubkey < ActiveRecord::Migration
	def up
		add_column :applications, :pubkey, :string
	end

	def down
		remove_column :applications, :pubkey
	end
end
