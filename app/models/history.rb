class History < ActiveRecord::Base
  self.table_name = 'histories'
  belongs_to :history_type,             :class_name => 'History::Type'
  belongs_to :history_object,           :class_name => 'History::Object'
  belongs_to :history_attribute,        :class_name => 'History::Attribute'
#  before_validation :check_type, :check_object
#  attr_writer :history_type, :history_object

  def self.history_create(data) 

    # lookups
    history_type = History::Type.where( :name => data[:history_type] ).first
    if !history_type || !history_type.id
      history_type = History::Type.create(
        :name   => data[:history_type]
      )
    end
    history_object = History::Object.where( :name => data[:history_object] ).first
    if !history_object || !history_object.id
      history_object = History::Object.create(
        :name   => data[:history_object]
      )
    end
    related_history_object_id = nil
    if data[:related_history_object]
      related_history_object = History::Object.where( :name => data[:related_history_object] ).first
      if !related_history_object || !related_history_object.id
        related_history_object = History::Object.create(
          :name   => data[:related_history_object]
        )
      end
      related_history_object_id = related_history_object.id
    end
    history_attribute_id = nil
    if data[:history_attribute]
      history_attribute = History::Attribute.where( :name => data[:history_attribute] ).first
      if !history_attribute || !history_attribute.object_id
        history_attribute = History::Attribute.create(
          :name   => data[:history_attribute]
        )
      end
      history_attribute_id = history_attribute.id
    end

    # create history
    History.create(
      :o_id                        => data[:o_id],
      :history_type_id             => history_type.id,
      :history_object_id           => history_object.id,
      :history_attribute_id        => history_attribute_id,
      :related_history_object_id   => related_history_object_id,
      :related_o_id                => data[:related_o_id],
      :value_from                  => data[:value_from],
      :value_to                    => data[:value_to],
      :id_from                     => data[:id_from],
      :id_to                       => data[:id_to],
      :created_by_id               => data[:created_by_id]
    )
    
  end

  def self.history_destroy(requested_object, requested_object_id)
    History.where( :history_object_id => History::Object.where( :name => requested_object ) ).
      where( :o_id => requested_object_id ).
      destroy_all
  end

  def self.history_list(requested_object, requested_object_id, related_history_object = nil)
    if !related_history_object
      history = History.where( :history_object_id => History::Object.where( :name => requested_object ) ).
        where( :o_id => requested_object_id ).
        where( :history_type_id => History::Type.where( :name => ['created', 'updated']) ).
        order('created_at ASC, id ASC')
    else
      history = History.where(
          '((history_object_id = ? AND o_id = ?) OR (history_object_id = ? AND related_o_id = ? )) AND history_type_id IN (?)',
          History::Object.where( :name => requested_object ).first.id,
          requested_object_id,
          History::Object.where( :name => related_history_object ).first.id,
          requested_object_id,
          History::Type.where( :name => ['created', 'updated'] )
        ).
        order('created_at ASC, id ASC')
    end
      
    list = []
    history.each { |item|
      item_tmp = item.attributes
      item_tmp['history_type'] = item.history_type.name
      item_tmp['history_object'] = item.history_object.name
      if item.history_attribute
       item_tmp['history_attribute'] = item.history_attribute.name
      end
      item_tmp.delete( 'history_attribute_id' )
      item_tmp.delete( 'history_object_id' )
      item_tmp.delete( 'history_type_id' )
      item_tmp.delete( 'o_id' )
      item_tmp.delete( 'updated_at' )
      if item_tmp['id_to'] == nil && item_tmp['id_from'] == nil
        item_tmp.delete( 'id_to' )
        item_tmp.delete( 'id_from' )        
      end
      if item_tmp['value_to'] == nil && item_tmp['value_from'] == nil
        item_tmp.delete( 'value_to' )
        item_tmp.delete( 'value_from' )        
      end
      if item_tmp['related_history_object_id'] == nil
        item_tmp.delete( 'related_history_object_id' )
      end
      if item_tmp['related_o_id'] == nil
        item_tmp.delete( 'related_o_id' )
      end
      list.push item_tmp
    }
    return list
  end
  
  def self.activity_stream(user, limit = 10)
#    g = Group.where( :active => true ).joins(:users).where( 'users.id' => user.id )
#    stream = History.select("distinct(histories.o_id), created_by_id, history_attribute_id, history_type_id, history_object_id, value_from, value_to").
#      where( :history_type_id   => History::Type.where( :name => ['created', 'updated']) ).
    stream = History.select("distinct(histories.o_id), created_by_id, history_type_id, history_object_id").
      where( :history_object_id => History::Object.where( :name => [ 'Ticket', 'Ticket::Article' ] ) ).
      where( :history_type_id   => History::Type.where( :name => [ 'created', 'updated' ]) ).
      order('created_at DESC, id DESC').
      limit(limit)
    datas = []
    stream.each do |item|
      data = item.attributes
      data['history_object'] = item.history_object.name
      data['history_type']   = item.history_type.name
      data.delete('history_object_id')
      data.delete('history_type_id')
      datas.push data
#      item['history_attribute'] = item.history_attribute
    end
    return datas
  end

  def self.recent_viewed(user)
#    g = Group.where( :active => true ).joins(:users).where( 'users.id' => user.id )
    stream = History.select("distinct(histories.o_id), created_by_id, history_attribute_id, history_type_id, history_object_id, value_from, value_to").
      where( :history_object_id => History::Object.where( :name => 'Ticket').first.id ).
      where( :history_type_id => History::Type.where( :name => ['viewed']) ).
      where( :created_by_id => user.id ).
      order('created_at DESC, id DESC').
      limit(10)
    datas = []
    stream.each do |item|
      data = item.attributes
      data['history_object'] = item.history_object
      data['history_type']   = item.history_type
      datas.push data
#      item['history_attribute'] = item.history_attribute
    end
    return datas
  end
  
  private
    def check_type
      puts '--------------'
      puts self.inspect
      history_type = History::Type.where( :name => self.history_type ).first
      if !history_type || !history_type.id
        history_type = History::Type.create(
          :name   => self.history_type,
          :active => true
        )
      end
      self.history_type_id = history_type.id
    end
    def check_object
      history_object = History::Object.where( :name => self.history_object ).first
      if !history_object || !history_object.id
        history_object = History::Object.create(
          :name   => self.history_object,
          :active => true
        )
      end
      self.history_object_id = history_object.id
    end

  class Object < ActiveRecord::Base
  end

  class Type < ActiveRecord::Base
  end

  class Attribute < ActiveRecord::Base
  end

end
