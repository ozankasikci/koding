class StaticGroupController extends KDController

  CONTENT_TYPES = [
    'CBlogPostActivity','CStatusActivity','CCodeSnipActivity',
    'CDiscussionActivity', 'CTutorialActivity'
  ]

  constructorToPluralNameMap =
    'CStatusActivity'     : 'Status Updates'
    'CBlogPostActivity'   : 'Blog Posts'
    'CCodeSnipActivity'   : 'Code Snippets'
    'CDiscussionActivity' : 'Discussions'
    'CTutorialActivity'   : 'Tutorials'

  roleEventMap =
    "guest"               : "status.guest"
    "member"              : "status.member"
    "invitation-pending"  : "status.pending"
    "invitation-sent"     : "status.action-required"
    "invitation-declined" : "status.declined"

  constructor:->

    super

    @group             = null
    @mainController    = @getSingleton "mainController"
    @lazyDomController = @getSingleton "lazyDomController"
    {@groupEntryPoint} = KD.config

    @reviveViews()
    @checkGroupUserRelation()
    @attachListeners()


    @registerSingleton 'staticGroupController', @, yes

  fetchGroup:(callback)->
    KD.remote.cacheable @groupEntryPoint, (err, groups, name)=>
      if err then callback err
      else if groups?.first
        @group = groups.first
        callback null, @group

  parseMenuItems :(callback)->

    cb = (group)=>
      group.fetchReadme (err,{content})=>
        unless err
          menuItems = []
          lines = content.split("\n");
          for line,index in lines
            if /^#[^#]{1,}/.test line
              menuItems.push
                title : line.replace(/^#*\s*/g, '')
                line  : index
            else if /^\s*(=){1,}\s*$/.test line
              menuItems.push
                title : lines[index-1]
                line  : index-1

          callback menuItems

    if @group then cb @group
    else @fetchGroup (err, group)-> cb group

  reviveViews :->

    @landingView = new KDView
      lazyDomId : 'static-landing-page'

    @landingView.listenWindowResize()
    @landingView._windowDidResize = =>
      {innerHeight} = window
      @landingView.setHeight innerHeight

    @groupContentWrapperView = new KDView
      lazyDomId : 'group-content-wrapper'
      cssClass : 'slideable'

    @groupTitleView = new KDView
      lazyDomId : 'group-title'
      click     : =>
        # @activityListWrapper.hide()
        @groupReadmeView.show()

    @groupReadmeView = new KDView
      lazyDomId : 'group-readme'


    @groupContentView = new KDScrollView
      lazyDomId : 'group-landing-content'
      scroll    : (event)=>
        if @groupContentView.getScrollTop() > 37
          @landingNav.setClass "in"
        else
          @landingNav.unsetClass "in"
        # log "scrolling", event

    @groupSplitView = new KDView
      lazyDomId : 'group-splitview'

    groupPersonalWrapperView = new KDView
      lazyDomId : 'group-personal-wrapper'
      cssClass  : 'slideable'
      click :(event)=>
        if event.target.id is 'group-personal-wrapper'
          @mainController.emit "landingSidebarClicked"

    groupLogoView = new KDView
      lazyDomId: 'group-koding-logo'
      click :=>
        groupPersonalWrapperView.setClass 'slide-down'
        @groupContentWrapperView.setClass 'slide-down'
        groupLogoView.setClass 'top'

        @landingView.setClass 'group-fading'
        @utils.wait 1100, => @landingView.setClass 'group-hidden'

    groupLogoView.setY @landingView.getHeight()-42

    @landingView.addSubView @landingNav = new KDCustomHTMLView
      tagName   : 'nav'
      lazyDomId : "landing-page-nav"

    @buttonWrapper = new KDCustomHTMLView
      cssClass : "button-wrapper"

    @buttonWrapper.addSubView @userButtonBar = new StaticUserButtonBar

    @utils.defer =>
      groupLogoView.setClass 'animate'
      @landingView._windowDidResize()

    @createGroupNavigation()

  createGroupNavigation:->

    @parseMenuItems (items)=>
      log items
      navController  = new KDListViewController
        view         : new KDListView
          itemClass  : GroupLandingNavItem
          wrapper    : no
          scrollView : no
          type       : "nav"
      # , {items}

      navController.getListView().on "viewAppended", =>
        navController.instantiateListItems items

      @landingNav.addSubView navController.getListView()

  checkGroupUserRelation:->
    cb = (group)=>
      group.fetchMembershipStatuses (err, statuses)=>
        if err then warn err
        else if statuses.length
          if "member" in statuses or "admin" in statuses
            isAdmin = 'admin' in statuses
            @emit roleEventMap.member, isAdmin
          else
            @emit roleEventMap[statuses.first]

      group.on 'NewMember', (member={})=>
        if member.profile?.nickname is KD.whoami().profile.nickname
          @pendingButton?.hide()
          @requestButton?.hide()
          @decorateMemberStatus no

    if @group then cb @group
    else @fetchGroup (err, group)-> cb group



  removeBackground:->
    @groupContentWrapperView.$().css backgroundImage : "none"
    @groupContentWrapperView.$().css backgroundColor : "#ffffff"

  setBackground:(type,val)->
    if type in ['defaultImage','customImage']
      @groupSplitView.unsetClass 'vignette'
      @groupContentView.$().css backgroundColor : 'white'
      @utils.wait 200, =>
        @groupContentWrapperView.$().css backgroundImage : "url(#{val})"
        @utils.wait 200, =>
          @groupContentView.$().css backgroundColor : 'transparent'
    else
      @groupSplitView.setClass 'vignette'
      @groupContentWrapperView.$().css backgroundImage : "none"
      @groupContentWrapperView.$().css backgroundColor : "#{val}"

  attachListeners:->

    @on "status.pending", @bound "decoratePendingStatus"
    @on "status.member",  @bound "decorateMemberStatus"
    @on "status.guest",   @bound "decorateGuestStatus"

    @on "AccessIsRequested", @bound "decoratePendingStatus"

    @mainController.on "accountChanged.to.loggedOut", =>
      @buttonWrapper.destroySubViews()

    @mainController.on "accountChanged.to.loggedIn", =>
      @checkGroupUserRelation()

  decoratePendingStatus:->

    @requestButton?.hide()
    @pendingButton = new CustomLinkView
      title    : "REQUEST PENDING"
      cssClass : "request-pending"
      icon     : {}
      click    : (event)=> event.preventDefault()

    @buttonWrapper.addSubView @pendingButton

  decorateMemberStatus:(isAdmin)->

    open = new CustomLinkView
      title    : "Open group"
      cssClass : "open"
      icon     : {}
      click    : (event)=>
        event.preventDefault()
        @lazyDomController.openPath "/#{@groupEntryPoint}/Activity"

    @buttonWrapper.addSubView open

    if isAdmin
      # dashboard = new CustomLinkView
      #   title    : "Go to Dashboard"
      #   cssClass : "customize"
      #   icon     : {}
      #   click    : (event)=>
      #     event.preventDefault()
      #     @lazyDomController.openPath "/#{@groupEntryPoint}/Activity"

      # @buttonWrapper.addSubView dashboard

      @buttonWrapper.addSubView config = new CustomLinkView
        title    : "Customize"
        cssClass : "customize"
        icon     : {}
        click    : (event)=>
          event.preventDefault()
          if @groupContentWrapperView.$().hasClass  'edit'
            @groupContentWrapperView.unsetClass     'hide-front'
            @utils.wait 200, =>
              @groupContentWrapperView.unsetClass   'edit'
          else
            # scroll only if there is a distance to scroll
            unless @groupContentView.$().scrollTop() is 0
              @groupContentView.$().animate
                scrollTop : 0
              ,200, 'swing', =>
                @groupContentWrapperView.setClass   'edit'
                @utils.wait 800, =>
                  @groupContentWrapperView.setClass 'hide-front'
            else
              # immediately flip otherwise
              @groupContentWrapperView.setClass     'edit'

      groupConfigView = new KDView
        lazyDomId : 'group-config'

      groupConfigView.addSubView new StaticGroupCustomizeView
        delegate : @
      ,@getData()



  decorateGuestStatus:->

    @requestButton = new CustomLinkView
      title    : "Request Access"
      cssClass : "request"
      icon     : {}
      click    : (event)=>
        event.preventDefault()
        @lazyDomController.requestAccess()

    @buttonWrapper.addSubView @requestButton

    if KD.isLoggedIn()
      KD.remote.api.JMembershipPolicy.byGroupSlug @groupEntryPoint, (err, policy)=>
        if err then console.warn err
        else unless policy?.approvalEnabled
          @requestButton.destroy()
          @requestButton = new CustomLinkView
            title    : "Join Group"
            cssClass : "join"
            icon     : {}
            click    : (event)=>
              event.preventDefault()
              @lazyDomController.handleNavigationItemClick
                action  : 'join-group'

          @buttonWrapper.addSubView @requestButton


class GroupLandingNavItem extends KDListItemView

  constructor:(options = {}, data)->

    options.tagName    or= "a"
    options.attributes   =
      href               : "#"

    super options, data

  viewAppended: JView::viewAppended

  click:(event)->
    event.preventDefault()

  pistachio:-> "{{ #(title)}}"
