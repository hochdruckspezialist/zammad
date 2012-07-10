$ = jQuery.sub()

class App.DashboardActivityStream extends App.Controller
  events:
    'click [data-type=edit]': 'zoom'

  constructor: ->
    super
    @items = []
    
    # refresh list ever 140 sec.
    @interval( @fetch, 1400000, 'dashboard_activity_stream' )
    
  fetch: =>
    
    # use cache of first page
    if window.LastRefresh[ 'dashboard_activity_stream' ]
      @render( window.LastRefresh[ 'dashboard_activity_stream' ] )
    
    # get data
    if @req
      @req.abort()
    @ajax = new App.Ajax
    @req = @ajax.ajax(
      type:  'GET',
      url:   '/activity_stream',
      data:  {
        limit: @limit,
      }
      processData: true,
      success: @load
    )
    
  load: (data) =>
    items = data.activity_stream

    # load user collection
    @loadCollection( type: 'User', data: data.users )

    # load ticket collection
    @loadCollection( type: 'Ticket', data: data.tickets )

    # load article collection
    @loadCollection( type: 'TicketArticle', data: data.articles )

    # set cache
    window.LastRefresh[ 'dashboard_activity_stream' ] = items

    @render(items)

  render: (items) ->

    # load user data
    for item in items
      item.created_by = App.User.find( item.created_by_id )
  
    # load ticket data
    for item in items
      item.data = {}
      if item.history_object is 'Ticket'
        item.data.title = App.Ticket.find( item.o_id ).title
      if item.history_object is 'Ticket::Article'
        article = App.TicketArticle.find( item.o_id )
        item.history_object = 'Article'
        item.sub_o_id = article.id
        item.o_id = article.ticket_id
        item.data.title = article.subject
  
    html = App.view('dashboard/activity_stream')(
      head: 'Activity Stream',
      items: items
    )
    html = $(html)
    
    @html html

    # start user popups
    @userPopups('left')

  zoom: (e) =>
    e.preventDefault()
    id = $(e.target).parents('[data-id]').data('id')
    subid = $(e.target).parents('[data-subid]').data('subid')
    @log 'goto zoom!', id, subid
    if subid
      @navigate 'ticket/zoom/' + id + '/' + subid
    else
      @navigate 'ticket/zoom/' + id
