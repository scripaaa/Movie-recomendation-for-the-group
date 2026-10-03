class AddNicknameToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :nickname, :string

    execute("SELECT id FROM users ORDER BY id").each do |row|
      id = row.fetch("id")
      execute("UPDATE users SET nickname = #{connection.quote("user#{id}")} WHERE id = #{connection.quote(id)}")
    end

    change_column_null :users, :nickname, false
    add_index :users, :nickname, unique: true
  end

  def down
    remove_index :users, :nickname
    remove_column :users, :nickname
  end
end
