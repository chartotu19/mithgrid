#
# We place most of the data-centric pieces in the MITHgrid.Data namespace.
#
MITHgrid.namespace 'Data', (Data) ->
  Data.namespace 'Set', (Set) ->
    # # Data Sets
    #
    # Sets track membership of string item IDs.
    # Sets are basic objects that do not participate in the MITHgrid.initInstance scheme.
    #
    # ## Set.initInstance
    #
    # Initializes a set.
    #
    # Parameters:
    #
    # * values - optional array of values that are initial members of the set
    #
    # Returns:
    #
    # The set object.
    #
    Set.initInstance = (values) ->
      that = {}
      items = {}
      count = 0
      recalc_items = true
      items_list = []

      # ### #items
      #
      # Returns a list of item IDs in the set.
      #
      # Parameters: None.
      #
      # Returns:
      #
      # An array of item IDs.
      #
      that.items = () ->
        if recalc_items
          items_list = []
          for i of items
            items_list.push i if typeof(i) == "string" and items[i] == true
        items_list

      # ### #add
      #
      # Adds an item ID to the set.
      #
      # Parameters:
      #
      # * item - item ID to be added to the set
      #
      # Returns:
      #
      # Returns nothing.
      #
      that.add = (item) ->
        if !items[item]?
          items[item] = true
          recalc_items = true
          count += 1

      # ### #remove
      #
      # Removes the item ID from the set.
      #
      # Parameters:
      #
      # * item - item ID to be removed from the set
      #
      # Returns:
      #
      # Returns nothing.
      #
      that.remove = (item) ->
        if items[item]?
          delete items[item]
          recalc_items = true
          count -= 1
      
      # ### #empty
      #
      # Removes all items from the set.
      #
      # Parameters: None.
      #
      # Returns:
      #
      # Returns nothing.
      #
      that.empty = () ->
        items = {}
        count = 0
        recalc_items = false
        items_list = []
        false

      # ### #visit
      #
      # Calls a function with each item ID in the set. This will terminate if the called function returns the
      # "true" value.
      #
      # Parameters:
      #
      # * fn - function taking one argument (the item ID being visited)
      #
      # Returns:
      #
      # Returns nothing.
      #
      that.visit = (fn) ->
        for o of items
          break if fn(o) == true
        false

      # ### #contains
      #
      # Returns true if the item ID is in the set.
      #
      # Parameters:
      #
      # * o - item ID to be tested
      #
      # Returns:
      #
      # True or false depending on the presence of the item ID in the set.
      #
      that.contains = (o) ->
        items[o]?

      # ### #size
      #
      # Returns the number of item IDs in the set.
      #
      # Parameters: None.
      #
      # Returns:
      #
      # The number of item IDs in the set.
      #
      that.size = () ->
        if recalc_items
          that.items().length
        else
          items_list.length

      if values instanceof Array
        that.add i for i in values

      that
    

  
  # # Data Types
  #
  # This object type is used to encapsulate information about item types. Used within data store objects and parsed
  # expressions.
  #
  Data.namespace 'Type', (Type) ->
    Type.initInstance = (t) ->
      that =
        name: t
        custom: {}
  
  # # Data Properties
  #
  # This object type is used to encapsulate information about item properties. Used within data store objects and
  # parsed expressions.
  #
  Data.namespace 'Property', (Property) ->
    Property.initInstance = (p) ->
      that =
        name: p
        getValueType: () ->
          that.valueType ? 'text'
  
  # # Data Store
  #
  # MITHgrid.Data.Store is a basic triple store that allows updating and deletion of triples.
  # Data stores are usually used as sources for data views.
  # The data store supports export and import of JSON-LD data.
  #
  Data.namespace 'Store', (Store) ->
    # ## Store.initInstance
    #
    # Initializes a data store instance.
    #
    # Parameters:
    #
    # * options - object containing configuration options
    #
    # Returns:
    #
    # The configured data store instance.
    #
    Store.initInstance = (args...) ->
      MITHgrid.initInstance "MITHgrid.Data.Store", args..., (that) -> # we don't use container
        quiesc_events = false
        set = Data.Set.initInstance()
        types = {}
        properties = {}
        spo = {}
        ops = {}
  
        options = that.options

        # ### #items (see Set#items)
        that.items = set.items
      
        # ### #contains (see Set#contains)
        that.contains = set.contains
      
        # ### #visit (see Set#visit)
        that.visit = set.visit
      
        # ### #size (see Set#size)
        that.size = set.size

        # ### indexPut (private)
        #
        # Puts a triple into an index. This manages reference counting.
        #
        # Parameters:
        #
        # * index - the index to which the triple is added
        # * x, y, z - the triple to insert into the index (s,p,o or o,p,s)
        #
        # Returns: Nothing.
        #
        indexPut = (index, x, y, z) ->
          hash = index[x]

          if !hash?
            hash =
              values: {}
              counts: {}
            index[x] = hash
            hash.values[y] = [ z ]
            hash.counts[y] = { }
            hash.counts[y][z] = 1
          else
            values = hash.values
            counts = hash.counts

            if !values[y]?
              values[y] = [ z ]
              counts[y] = {}
              counts[y][z] = 1
            else 
              if counts[y][z]?
                counts[y][z] += 1
              else
                values[y].push z
                counts[y][z] = 1

        # ### indexFillSet (private)
        #
        # Parameters:
        #
        # * index
        # * x, y
        # * set
        # * filter
        #
        # Returns: Nothing.
        #
        indexFillSet = (index, x, y, set, filter) ->
          hash = index[x]

          if hash?
            array = hash.values[y]
            if array?
              if filter?
                for z in array
                  set.add z if filter.contains z
              else
                set.add z for z in array
          false

        # ### getUnion (private)
        #
        # Parameters:
        #
        # * index
        # * xSet
        # * y
        # * set
        # * filter
        #
        # Returns:
        #
        # If set is not defined, then a new set is created and returned. Otherwise, the set passed in is returned
        # with the additional items added.
        #
        getUnion = (index, xSet, y, set, filter) ->
          if !set?
            set = Data.Set.initInstance()

          xSet.visit (x) -> indexFillSet index, x, y, set, filter
          set

        # ### #addProperty
        #
        # Adds metadata about a property.
        #
        # Parameters:
        #
        # * nom - property name
        # * options - object holding metadata about the property
        #
        # Returns:
        #
        # The property object holding the information.
        #
        that.addProperty = (nom, options) ->
          prop = Data.Property.initInstance nom
          if options?.valueType?
            prop.valueType = options.valueType
            properties[nom] = prop
          prop

        # ### #getProperty
        #
        # Returns the property object holding the related metadata.
        #
        # Parameters:
        #
        # * nom - property name
        #
        # Returns:
        #
        # Object holding the property metadata.
        #
        that.getProperty = (nom) -> properties[nom] ? Data.Property.initInstance(nom)

        # ### #addType
        #
        # Adds metadata about a type.
        #
        # Parameters:
        #
        # * nom - type name
        # * options - object holding metadata about the type
        #
        # Returns:
        #
        # The type object holding the information.
        #
        that.addType = (nom, options) ->
          type = Data.Type.initInstance(nom)
          types[nom] = type
          type

        # ### #getType
        #
        # Returns the type object holding the related metadata.
        #
        # Parameters:
        #
        # * nom - type name
        #
        # Returns:
        #
        # Object holding the type metadata.
        #
        that.getType = (nom) -> types[nom] ? Data.Type.initInstance(nom)

        # ### #getItem
        #
        # Returns the triples related to an item ID
        #
        # Parameters:
        #
        # * id - item ID
        # * cb - optional callback to receive the item
        #
        # Returns:
        #
        # An object containing the triples related to the item ID. If the item ID is not in the data store, then
        # and empty object is returned.
        #
        that.getItem = (id, cb) -> 
          result = spo[id]?.values ? {}
          if cb
            cb null, result
          else
            result

        # ### #getItems
        #
        # Returns an array of objects holding the triples associated with an array of item IDs.
        #
        # Parameters:
        #
        # * ids - array of item IDs
        # * cb - optional callback to receive results
        #
        # Returns:
        #
        # An array of objects containing the triples related to the item IDs.
        # If you provide a callback function, then the results will be passed to the callback
        # one at a time, ending with null.
        #
        # The callback function has the signature (err, doc):
        #
        #     dataStore.getItems([id list...], function(err, item) { ... });
        #
        that.getItems = (ids, cb) ->
          if cb?
            sync = MITHgrid.initSyncronizer cb
            if ids.length?
              for id in ids
                sync.increment()
                that.getItem id, (err, res) ->
                  cb err, res
                  sync.decrement()
            else
              sync.increment()
              that.getItem ids, (err, res) ->
                cb err, res
                sync.decrement()
            sync.done()
          else
            if ids.length
              (that.getItem id for id in ids)
            else
              [ that.getItem ids ]
        
        # ### #removeItems
        #
        # Removes triples associated with the item IDs.
        #
        # Parameters:
        #
        # * ids - list of item IDs
        # * fn - callback function
        #
        # Returns: Nothing
        #
        # Events:
        #
        # * onModelChange
        #
        that.removeItems = (ids, fn) ->
          id_list = []
    
          # #### indexRemove (private to #removeItems)
          #
          # Removes a triple from an index if the reference count is zero.
          #
          # Parameters:
          #
          # * index
          # * x, y, z
          #
          # Returns: Nothing.
          #
          indexRemove = (index, x, y, z) ->
            hash = index[x]
            return if !hash?

            array = hash.values[y];
            counts = hash.counts[y];

            return if !array? or !counts?

            counts[z] -= 1
            if counts[z] < 1
              i = $.inArray z, array
              if i == 0
                array = array[1...array.length]
              else if i == array.length - 1
                array = array[0 ... i]
              else if i > 0
                array = array[0 ... i].concat array[i + 1 ... array.length]
              if array.length > 0
                hash.values[y] = array
              else
                delete hash.values[y]
              delete counts[z]
              # TODO: if counts empty, then we need to bubble up the deletion
              sum = 0
              for k, v of counts
                sum += v
              if sum == 0
                delete index[x]
            false

          # #### indexRemoveFn (private to #removeItems)
          #
          # Removes the triple from the forward and backward indices.
          #
          # Parameters:
          #
          # * s - subject (item ID)
          # * p - predicate (property)
          # * o - object (value)
          #
          # Returns: Nothing.
          #
          indexRemoveFn = (s, p, o) ->
            indexRemove spo, s, p, o
            indexRemove ops, o, p, s
    
          # #### removeValues (private to #removeItems)
          #
          # Removes the listed values for the property associated with the item ID.
          #
          # Parameters:
          #
          # * id - item ID
          # * p - property name
          # * list - list of values associated with the property
          #
          # Returns: Nothing
          #
          removeValues = (id, p, list) -> indexRemoveFn(id, p, o) for o in list
    
          # #### removeItem (private to #removeItems)
          #
          # Removes the item from the data store.
          #
          # Parameters:
          #
          # * id - item ID
          #
          # Returns: Nothing.
          # 
          removeItem = (id) ->
            entry = that.getItem id
      
            for p, items of entry
              continue if typeof(p) != "string" or p in ["id"]
              removeValues id, p, items
      
            removeValues id, 'id', [ id ]
      
        
          for id in ids
            removeItem id
            id_list.push id
            set.remove id
      
          that.events.onModelChange.fire that, id_list
          if fn?
            fn()
          
        # ### #updateItems
        #
        that.updateItems = (items, fn) ->
          id_list = []

          # #### indexRemove (private to #updateItems)
          indexRemove = (index, x, y, z) ->
            hash = index[x]
            return if !hash?

            array = hash.values[y]
            counts = hash.counts[y]

            return if !array? or !counts?
            # we need to remove the old z values
            counts[z] -= 1
            if counts[z] < 1
              i = $.inArray z, array
              if i == 0
                array = array[1...array.length]
              else if i == array.length - 1
                array = array[0 ... i]
              else if i > 0
                array = array[0 ... i].concat array[i + 1 ... array.length]
              if array.length > 0
                hash.values[y] = array
              else
                delete hash.values[y]
              delete counts[z]
          
          # #### indexPutFn (private to #updateItems)
          indexPutFn = (s, p, o) ->
            indexPut spo, s, p, o
            indexPut ops, o, p, s

          # #### indexRemoveFn (private to #updateItems)
          indexRemoveFn = (s, p, o) ->
            indexRemove spo, s, p, o
            indexRemove ops, o, p, s

          # #### updateItem (private to #updateItems)
          updateItem = (entry) ->
            # we only update things that are different from the old_item
            # we also only update properties that are in the new item
            # if anything is changed, we return true
            # otherwise, we return false
            id = entry.id
            changed = false

            itemListIdentical = (to, from) ->
              items_same = true
              return false if to.length != from.length
              for i in [0...to.length]
                if to[i] != from[i]
                  items_same = false
              items_same

            removeValues = (id, p, list) -> indexRemoveFn(id, p, o) for o in list
            putValues = (id, p, list) -> indexPutFn(id, p, o) for o in list
      
            id = id[0] if $.isArray(id)

            old_item = that.getItem id

            for p, items of entry
              continue if typeof(p) != "string" or p in ["id"]

              # if entry[p] and old_item[p] have the same members in the same order, then
              # we do nothing

              items = [items] if !$.isArray(items)
              s = items.length;
              if !old_item[p]?
                putValues id, p, items
                changed = true
              else if !itemListIdentical items, old_item[p]
                changed = true
                removeValues id, p, old_item[p]
                putValues id, p, items
            changed

          that.events.onBeforeUpdating.fire that

          n = items.length
          chunk_size = parseInt(n / 100, 10)
          chunk_size = 500 if chunk_size > 500
          chunk_size = 100 if chunk_size < 100

          f = (start) ->
            end = start + chunk_size;
            end = n if end > n

            for i in [start ... end]
              entry = items[i]
              if typeof(entry) == "object" and updateItem entry
                id_list.push entry.id

            if end < n
              setTimeout () ->
                f end
              ,
              0
            else
              that.events.onAfterUpdating.fire that
              that.events.onModelChange.fire that, id_list
              if fn?
                fn()
          f 0

        # ### #loadItems
        that.loadItems = (items, endFn) ->
          id_list = []

          # #### indexFn (private to #loadItems)
          indexFn = (s, p, o) ->
            indexPut spo, s, p, o
            indexPut ops, o, p, s

          # #### loadItem (private to #loadItems)
          loadItem = (item) ->
            if !item.id?
              throw MITHgrid.error "Item entry has no id: ", item
            if !item.type?
              throw MITHgrid.error "Item entry has no type: ", item

            id = item.id

            id = id[0] if $.isArray id

            set.add id
            id_list.push id

            indexFn id, "id", id
      
            for p, v of item
              if typeof(p) != "string"
                continue
          
              if p not in ["id"]
                if $.isArray(v)
                  indexFn id, p, vv for vv in v
                else if v?
                  indexFn id, p, v
          that.events.onBeforeLoading.fire that
    
          n = items.length
          if endFn?
            chunk_size = parseInt(n / 100, 10)
            chunk_size = 500 if chunk_size > 500
          else
            chunk_size = n
          chunk_size = 100 if chunk_size < 100
    
          f = (start) ->
            end = start + chunk_size
            end = n if end > n

            for i in [ start ... end ]
              entry = items[i]
              loadItem entry if typeof(entry) == "object"

            if end < n
              setTimeout () ->
                f(end)
              , 0
            else
              that.events.onAfterLoading.fire that
              that.events.onModelChange.fire that, id_list
              endFn() if endFn?
          f 0

        # ### #prepare
        #
        that.prepare = (expressions) ->
          parser = MITHgrid.Expression.Basic.initInstance()
          parsed = (parser.parse(ex) for ex in expressions)
          valueType = undefined
          evaluate: (id) ->
            values = []
            valueType = undefined
            for ex in parsed
              do (ex) ->
                items = ex.evaluateOnItem id, that
                valueType or= items.valueType
                values = values.concat items.values.items()
            values
          valueType: () -> valueType

        # ### #getObjectsUnion
        #
        that.getObjectsUnion = (subjects, p, set, filter) -> getUnion spo, subjects, p, set, filter
      
        # ### #getSubjectsUnion
        #
        that.getSubjectsUnion = (objects, p, set, filter) -> getUnion ops, objects,  p, set, filter

        # ### #registerPresentation
        #
        that.registerPresentation = (ob) ->
          ob.onDestroy that.events.onModelChange.addListener (m, i) -> ob.eventModelChange m, i
          ob.eventModelChange that, that.items()

  # # Data View
  #
  # Provides a filtered view of a data store based on configured filters (e.g., facets). The filtered view can
  # also be constrained based on item types or other simple property value expectations.
  #
  Data.namespace 'View', (View) ->
    # ## View.initInstance
    #
    View.initInstance = (args...) ->
      MITHgrid.initInstance "MITHgrid.Data.View", args..., (that) ->
  
        set = Data.Set.initInstance()
        options = that.options
  
        # ### filterItem (private)
        filterItem = (id) ->
          false != that.events.onFilterItem.fire that.dataStore, id

        # ### filterItems (private)
        filterItems = (endFn) ->
          ids = that.dataStore.items()
          n = ids.length
          if n == 0
            endFn()
            return

          if n > 200
            chunk_size = parseInt(n / 100, 10)
            chunk_size = 500 if chunk_size > 500
          else
            chunk_size = n
          chunk_size = 100 if chunk_size < 100

          f = (start) ->
            end = start + chunk_size
            end = n if end > n

            for i in [ start ... end ]
              id = ids[i]
              if filterItem id
                set.add id
              else
                set.remove id
            if end < n
              setTimeout () ->
                f end
              , 0
            else
              that.items = set.items
              that.size = set.size
              that.contains = set.contains
              that.visit = set.visit
              endFn() if endFn?
          f 0

        # ### #registerFilter
        #
        that.registerFilter = (ob) ->
          that.events.onFilterItem.addListener (x, y) -> ob.eventFilterItem x, y
          that.events.onModelChange.addListener (m, i) -> ob.eventModelChange m, i
          ob.events.onFilterChange.addListener that.eventFilterChange

        # ### #registerPresentation
        #
        that.registerPresentation = (ob) ->
          ob.onDestroy that.events.onModelChange.addListener (m, i) -> ob.eventModelChange m, i
          filterItems -> ob.eventModelChange that, that.items()

      
        # ### #items (see Set#items)
        that.items = set.items

        # ### #contains (see Set#contains)
        that.contains = set.contains

        # ### #visit (see Set#visit)
        that.visit = set.visit

        # ### #size (see Set#size)
        that.size = set.size
  
        that.eventFilterChange = () ->
          current_set = Data.Set.initInstance that.items()
          filterItems () ->
            changed_set = Data.Set.initInstance()
            for i in current_set.items()
              if !that.contains i
                changed_set.add i
            for i in that.items()
              if !current_set.contains i
                changed_set.add i
            if changed_set.size() > 0
              that.events.onModelChange.fire that, changed_set.items()
      
        that.eventModelChange = (model, items) ->
          changed_set = Data.Set.initInstance()
      
          for id in items
            if model.contains id
              if filterItem id
                set.add id
                changed_set.add id
              else
                if set.contains id
                  changed_set.add id
                  set.remove id
            else
              changed_set.add id
              set.remove id

          that.events.onModelChange.fire that, changed_set.items()

        if options?.types?.length > 0
          ((types) ->
            that.registerFilter
              eventFilterItem: (model, id) ->
                item = model.getItem id
                return false if !item.type?
                for t in types
                  return if t in item.type
                return false
              eventModelChange: (x, y) ->
              events:
                onFilterChange:
                  addListener: (x) ->
          )(options.types)

        if options?.filters?.length > 0
          ((filters) ->
            parser = MITHgrid.Expression.Basic.initInstance()
            parsedFilters = (parser.parse(ex) for ex in filters)
            that.registerFilter
              eventFilterItem: (model, id) ->
                for ex in parsedFilters
                  values = ex.evaluateOnItem(id, model)
                  values = values.values.items()
                  for v in values
                    return if v != "false"
                return false
              eventModelChange: (x, y) ->
              events:
                onFilterChange:
                  addListener: (x) ->
          )(options.filters)

        if options?.collection?
          that.registerFilter
            eventFilterItem: options.collection
            eventModelChange: (x, y) ->
            events:
              onFilterChange:
                addListener: (x) ->

        if options?.expressions?
          # We want a way to make our set of items depend on running expressions on the items
          # passed to us from the parent dataView/dataStore.
          # It needs to be quick, similar to the current propagation of changes.
          # **N.B.:** These are not event-based expressions.
          # The expressions must result in itemIds that are contained in the parent dataStore.
          expressions = options.dataStore.prepare(options.expressions)
          prevEventModelChange = that.eventModelChange
          intermediateDataStore = MITHgrid.Data.Store.initInstance({})
          subjectSet = MITHgrid.Data.Set.initInstance()
          that.eventModelChange = (model, items) ->
            itemList = []
            removedItems = []
            intermediateSet = MITHgrid.Data.Set.initInstance()
            intermediateSet = intermediateDataStore.getObjectsUnion subjectSet, "mapsTo", intermediateSet
            for id in items
              if intermediateSet.contains(id)
                itemList.push id
                if !model.contains(id)
                  # we need to find everything that maps to id
                  idSet = MITHgrid.Data.Set.initInstance()
                  intermediateDataStore.getSubjectsUnion MITHgrid.Data.Set.initInstance([id]), "mapsTo", idSet
                  idSet.visit (x) ->
                    item = intermediateDataStore.getItem x
                    mapsTo = item.mapsTo
                    if mapsTo?
                      i = mapsTo.indexOf(id)
                      if i == 0
                        mapsTo = mapsTo[1 ... mapsTo.length]
                      else if i == mapsTo.length-1
                        mapsTo = mapsTo[0 ... mapsTo.length-1]
                      else if i > -1
                        mapsTo = mapsTo[0 ... i].concat mapsTo[i+1 ... mapsTo.length]
                      intermediateDataStore.updateItems [
                        id: x
                        mapsTo: mapsTo
                      ]     
              else if model.contains(id)
                itemSet = MITHgrid.Data.Set.initInstance()
                for v in expressions.evaluate([id])
                  itemSet.add(v)
                if intermediateDataStore.contains(id)
                  intermediateDataStore.updateItems [
                    id: id
                    mapsTo: itemSet.items()
                  ]
                else
                  intermediateDataStore.loadItems [
                    id: id
                    mapsTo: itemSet.items()
                  ]
              else
                # push onto itemList the items mapped to by this id
                itemList = itemList.concat(intermediateDataStore.getItem(id).mapsTo)
                removedItems.push id

            if removedItems.length > 0
              intermediateDataStore.removeItems(removedItems)

            intermediateSet = MITHgrid.Data.Set.initInstance()
            intermediateDataStore.getObjectsUnion subjectSet, "mapsTo", intermediateSet
            itemList = (item for item in itemList when item in items)
            prevEventModelChange intermediateSet, itemList

        that.dataStore = options.dataStore

        # ### #getItems (see Data Store #getItems)
        that.getItems = that.dataStore.getItems
      
        # ### #getItem (see Data Store #getItem)
        that.getItem = that.dataStore.getItem
      
        # ### #removeItems (see Data Store #removeItems)
        that.removeItems = that.dataStore.removeItems
      
        # ### #updateItems (see Data Store #updateItems)
        that.updateItems = that.dataStore.updateItems
      
        # ### #loadItems (see Data Store #loadItems)
        that.loadItems = that.dataStore.loadItems
      
        # ### #prepare (see Data Store #prepare)
        that.prepare = that.dataStore.prepare
      
        # ### #addType (see Data Store #addType)
        that.addType = that.dataStore.addType
      
        # ### #getType (see Data Store #getType)
        that.getType = that.dataStore.getType
      
        # ### #addProperty (see Data Store #addProperty)
        that.addProperty = that.dataStore.addProperty
      
        # ### #getProperty (see Data Store #getProperty)
        that.getProperty = that.dataStore.getProperty
      
        # ### #getObjectsUnion (see Data Store #getObjectsUnion)
        that.getObjectsUnion = that.dataStore.getObjectsUnion
      
        # ### #getSubjectsUnion (see Data Store #getSubjectsUnion)
        that.getSubjectsUnion = that.dataStore.getSubjectsUnion
  
        that.dataStore.events.onModelChange.addListener that.eventModelChange

        that.eventModelChange that.dataStore, that.dataStore.items()
  
  # # Data Subset View
  #
  Data.namespace 'SubSet', (SubSet) ->
    # ## SubSet.initInstance
    #
    # Given a set of expressions and a key value, the resulting set of items will consist of all items which
    # satisfy the expressions by producing the key value.
    #
    # Note that this is a fragile data view. Expressions that hop through other items may result in inconsistent
    # lists of items.
    #
    SubSet.initInstance = (args...) ->
      MITHgrid.initInstance "MITHgrid.Data.SubSet", args..., (that) ->
        options = that.options
  
        set = Data.Set.initInstance()

        # ### #items (see Set#items)
        that.items = set.items

        # ### #contains (see Set#contains)
        that.contains = set.contains

        # ### #visit (see Set#visit)
        that.visit = set.visit

        # ### #size (see Set#size)
        that.size = set.size
  
        # ### #setKey
        #
        that.setKey = (k) ->
          key = k

          newItems = Data.Set.initInstance(expressions.evaluate([key]))
          changed = []
          
          set.visit (i) ->
            if !newItems.contains i
              set.remove i
              changed.push i
              
          newItems.visit (i) ->
            if !set.contains i
              set.add i
              changed.push i

          if changed.length > 0
            that.events.onModelChange.fire that, changed

        expressions = options.dataStore.prepare(options.expressions)
      
        # ### #eventModelChange
        #
        that.eventModelChange = (model, items) ->
          if key?
            newItems = Data.Set.initInstance(expressions.evaluate([key]))
          else
            newItems = Data.Set.initInstance()
      
          changed = []
    
          for i in items
            if set.contains i
              changed.push i
              if !newItems.contains i
                set.remove i
            else if newItems.contains i
              set.add i
              changed.push i
          if changed.length > 0
            that.events.onModelChange.fire that, changed
        
        that.dataStore = options.dataStore

        # these mappings allow a data View to stand in for a data Store
        that.getItems = that.dataStore.getItems
        that.getItem = that.dataStore.getItem
        that.removeItems = that.dataStore.removeItems
        that.fetchData = that.dataStore.fetchData
        that.updateItems = that.dataStore.updateItems
        that.loadItems = that.dataStore.loadItems
        that.prepare = that.dataStore.prepare
        that.addType = that.dataStore.addType
        that.getType = that.dataStore.getType
        that.addProperty = that.dataStore.addProperty
        that.getProperty = that.dataStore.getProperty
        that.getObjectsUnion = that.dataStore.getObjectsUnion
        that.getSubjectsUnion = that.dataStore.getSubjectsUnion
  
        that.dataStore.events.onModelChange.addListener that.eventModelChange

        that.eventModelChange that.dataStore, that.dataStore.items()
  
        that.registerPresentation = (ob) ->
          ob.onDestroy that.events.onModelChange.addListener (m, i) -> ob.eventModelChange m, i
          ob.eventModelChange that, that.items()

        that.setKey options.key
    
  # # Data List Pager
  #
  # 
  Data.namespace 'ListPager', (ListPager) ->
    ListPager.initInstance = (args...) ->
      MITHgrid.initInstance "MITHgrid.Data.ListPager", args..., (that) ->
        options = that.options

        itemList = []
        itemListStart = 0
        itemListStop = -1
        leftKey = undefined
        rightKey = undefined
    
        findItemPosition = (itemId) -> itemList.indexOf itemId
    
        set = Data.Set.initInstance()

        that.items = set.items
        that.size = set.size
        that.contains = set.contains
        that.visit = set.visit

        that.dataStore = options.dataStore
        # these mappings allow a data pager to stand in for a data Store
        that.getItems = that.dataStore.getItems
        that.getItem = that.dataStore.getItem
        that.removeItems = that.dataStore.removeItems
        that.fetchData = that.dataStore.fetchData
        that.updateItems = that.dataStore.updateItems
        that.loadItems = that.dataStore.loadItems
        that.prepare = that.dataStore.prepare
        that.addType = that.dataStore.addType
        that.getType = that.dataStore.getType
        that.addProperty = that.dataStore.addProperty
        that.getProperty = that.dataStore.getProperty
        that.getObjectsUnion = that.dataStore.getObjectsUnion
        that.getSubjectsUnion = that.dataStore.getSubjectsUnion
  
        that.setList = (idList) ->
          itemList = idList
          changedItems = []
          for id in itemList
            if that.dataStore.contains(id) and !set.contains(id)
              if itemListStart <= itemList.indexOf(id) < itemListStop
                changedItems.push id
                set.add id
            else if set.contains(id) and !that.dataStore.contains(id)
              changedItems.push id
              set.remove id
          for id in set.items()
            if !id in itemList or !that.dataStore.contains id
              changedItems.push id
              set.remove id
          if changedItems.length > 0
            that.events.onModelChange.fire that, changedItems

        that.eventModelChange = (model, items) ->
          # we're modifying the items we're tracking, possibly expanding or decreasing the set
          changedItems = [] # to propogate on to the next level
          for itemId in items
            if model.contains(itemId)
              key = findItemPosition itemId
              if set.contains(itemId)
                changedItems.push itemId
                if !(itemListStart <= key < itemListStop)
                  set.remove itemId
              else
                if itemListStart <= key < itemListStop
                  set.add itemId
                  changedItems.push itemId
            else
              set.remove itemId
              changedItems.push itemId

          if changedItems.length > 0
            that.events.onModelChange.fire that, changedItems

        that.setKeyRange = (l, r) ->
          if l < r
            itemListStart = l
            itemListStop = r
          else
            itemListStart = r
            itemListStop = l
    
          oldSet = set
          changedItems = Data.Set.initInstance()
          set = Data.Set.initInstance()
          that.items = set.items
          that.size = set.size
          that.contains = set.contains
          that.visit = set.visit
    
          if itemListStart < itemListStop
            for i in [itemListStart..itemListStop]
              itemId = itemList[i]
              if !oldSet.contains(itemId)
                changedItems.add itemId
              set.add(itemId)
          oldSet.visit (x) ->
            if !set.contains(x)
              changedItems.add x
          if changedItems.size() > 0
            that.events.onModelChange.fire that, changedItems.items()

  
        that.dataStore.registerPresentation that

        that.registerPresentation = (ob) ->
          ob.onDestroy that.events.onModelChange.addListener (m, i) -> ob.eventModelChange m, i
          ob.eventModelChange that, that.items()

  # # Data Pager
  #
  Data.namespace 'Pager', (Pager) ->
    Pager.initInstance = (args...) ->
      MITHgrid.initInstance "MITHgrid.Data.Pager", args..., (that) ->
        options = that.options

        itemList = []
        itemListStart = -1
        itemListStop = -1
        leftKey = undefined
        rightKey = undefined
  
        # returns the first index that has a key greater than or equal to the given key
        findLeftPoint = (key) ->
          if !key?
            return 0
          left = 0
          right = itemList.length - 1
          while left < right
            mid = ~~((left + right) / 2)
    
            if itemList[mid][0] < key
              left = mid + 1
            else if itemList[mid][0] == key
              right = mid
            else
              right = mid - 1
          while itemList[left]? and itemList[left][0] < key
            left += 1
          left
    
        # returns the last index that has a key less than or equal to the given key
        findRightPoint = (key) ->
          if !key?
            return itemList.length - 1
          left = 0
          right = itemList.length - 1
          while left < right
            mid = ~~((left + right) / 2)
            if itemList[mid][0] < key
              left = mid + 1
            else
              right = mid - 1
          while right >= 0 and itemList[right][0] >= key
            right -= 1
          right
    
        findItemPosition = (itemId) ->
          for i in [0 ... itemList.length]
            return i if itemList[i][1] == itemId
          return -1
    

        set = Data.Set.initInstance()
  
        that.items = set.items
        that.size = set.size
        that.contains = set.contains
        that.visit = set.visit
  
        that.dataStore = options.dataStore
        # these mappings allow a data pager to stand in for a data Store
        that.getItems = that.dataStore.getItems
        that.getItem = that.dataStore.getItem
        that.removeItems = that.dataStore.removeItems
        that.fetchData = that.dataStore.fetchData
        that.updateItems = that.dataStore.updateItems
        that.loadItems = that.dataStore.loadItems
        that.prepare = that.dataStore.prepare
        that.addType = that.dataStore.addType
        that.getType = that.dataStore.getType
        that.addProperty = that.dataStore.addProperty
        that.getProperty = that.dataStore.getProperty
        that.getObjectsUnion = that.dataStore.getObjectsUnion
        that.getSubjectsUnion = that.dataStore.getSubjectsUnion
  
        expressions = that.prepare(options.expressions)
    
        that.eventModelChange = (model, items) ->
          # we're modifying the items we're tracking, possibly expanding or decreasing the set
          changedItems = [] # to propogate on to the next level
          for itemId in items
            if model.contains(itemId)
              keys = expressions.evaluate(itemId)
              if keys.length > 0
                if expressions.valueType() == "numeric"
                  key = parseFloat(keys[0])
                else
                  key = keys[0]
                if set.contains(itemId)
                  i = findItemPosition itemId
                  if i == -1
                    itemList.push [ key, itemId ]
                  else
                    itemList[i][0] = key
                  changedItems.push itemId
                  if leftKey? and key < leftKey or rightKey? and key >= rightKey
                    set.remove(itemId)
                else
                  itemList.push [ key, itemId ]
                  if (!leftKey? or key >= leftKey) and (!rightKey? or key < rightKey)
                    set.add(itemId)
                    changedItems.push itemId              
              else
                if set.contains(itemId)
                  i = findItemPosition itemId
                  if i == 0
                    itemList = itemList[1...itemList.length]
                  else if i == itemList.length-1
                    itemList = itemList[0...itemList.length-1]
                  else if i != -1
                    itemList = itemList[0...i].concat itemList[i+1...itemList.length]
                  set.remove(itemId)
                  changedItems.push itemId
            else
              set.remove itemId
              changedItems.push itemId
          # now sort itemList
          # and redo left and right positions
          # and double check set and changedItems list?
          itemList.sort (a,b) ->
            return -1 if a[0] < b[0]
            return  1 if a[0] > b[0]
            return  0
          itemListStart = findLeftPoint leftKey
          itemListStop  = findRightPoint rightKey

          if changedItems.length > 0
            that.events.onModelChange.fire that, changedItems

        that.setKeyRange = (l, r) ->
          if l? and r?
            if l < r
              leftKey = l
              rightKey = r
            else
              leftKey = r
              rightKey = l
          else
            leftKey = l
            rightKey = r
      
          
          itemListStart = findLeftPoint leftKey
          itemListStop  = findRightPoint rightKey

          changedItems = Data.Set.initInstance()
          oldSet = set
    
          set = Data.Set.initInstance()
          that.items = set.items
          that.size = set.size
          that.contains = set.contains
          that.visit = set.visit
    
          if itemListStart <= itemListStop
            for i in [itemListStart..itemListStop]
              itemId = itemList[i][1]
              if !oldSet.contains(itemId)
                changedItems.add itemId
              set.add(itemId)
          oldSet.visit (x) ->
            if !set.contains(x)
              changedItems.add x
          if changedItems.size() > 0
            that.events.onModelChange.fire that, changedItems.items()
  
        that.dataStore.registerPresentation that

        that.registerPresentation = (ob) ->
          ob.onDestroy that.events.onModelChange.addListener (m, i) -> ob.eventModelChange m, i
          ob.eventModelChange that, that.items()

  # # Data Range Pager
  #
  Data.namespace 'RangePager', (RangePager) ->
    RangePager.initInstance = (args...) ->
      MITHgrid.initInstance "MITHgrid.Data.RangePager", args..., (that) ->
        options = that.options

        leftPager = Data.Pager.initInstance
          dataStore: options.dataStore
          expressions: options.leftExpressions
        rightPager = Data.Pager.initInstance
          dataStore: options.dataStore
          expressions: options.rightExpressions
  
        set = Data.Set.initInstance()
        that.items = set.items
        that.size = set.size
        that.contains = set.contains
        that.visit = set.visit
  
        that.dataStore = options.dataStore
        # these mappings allow a data pager to stand in for a data Store
        that.getItems = that.dataStore.getItems
        that.getItem = that.dataStore.getItem
        that.removeItems = that.dataStore.removeItems
        that.fetchData = that.dataStore.fetchData
        that.updateItems = that.dataStore.updateItems
        that.loadItems = that.dataStore.loadItems
        that.prepare = that.dataStore.prepare
        that.addType = that.dataStore.addType
        that.getType = that.dataStore.getType
        that.addProperty = that.dataStore.addProperty
        that.getProperty = that.dataStore.getProperty
        that.getObjectsUnion = that.dataStore.getObjectsUnion
        that.getSubjectsUnion = that.dataStore.getSubjectsUnion
    
        that.eventModelChange = (model, itemIds) ->
          changedIds = []
          for id in itemIds
            if leftPager.contains(id) and rightPager.contains(id)
              changedIds.push id
              set.add id
            else if set.contains id
              changedIds.push id
              set.remove id
          that.events.onModelChange.fire that, changedIds 

        that.setKeyRange = (l, r) ->
          if l? and r? and l > r
            [l, r] = [r, l]
    
          leftPager.setKeyRange  undefined, r
          rightPager.setKeyRange l, undefined

        leftPager.registerPresentation that
        rightPager.registerPresentation that
        
        that.setKeyRange undefined, undefined
        
        that.registerPresentation = (ob) ->
          ob.onDestroy that.events.onModelChange.addListener (m, i) -> ob.eventModelChange m, i
          ob.eventModelChange that, that.items()
