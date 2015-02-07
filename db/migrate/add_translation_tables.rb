class CreateTranslationRecords < ActiveRecord::Migration
  def self.up
    create_table :translation_records do |t|
      t.integer :id
      t.string :locale
      t.integer :translator_id
      t.string :key
      t.text :value
      t.date :created_at
    end
    
    create_table :dynamic_translation_records do |t|
      :id, :locale, :translator_id, :model_type, :model_id, :column, :value, :date
      t.integer :id
      t.string :locale
      t.integer :translator_id
      t.string :model_type
      t.integer :model_id
      t.string :column
      t.text :value
      t.date :created_at
    end
  end

  def self.down
    drop_table :translation_records
    drop_table :dynamic_translation_records
  end
end