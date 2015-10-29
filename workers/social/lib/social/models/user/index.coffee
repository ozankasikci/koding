jraphical        = require 'jraphical'
Regions          = require 'koding-regions'
request          = require 'request'
{ argv }         = require 'optimist'
KONFIG           = require('koding-config-manager').load("main.#{argv.c}")
Flaggable        = require '../../traits/flaggable'
KodingError      = require '../../error'
emailsanitize    = require './emailsanitize'
{ extend, uniq } = require 'underscore'

module.exports = class JUser extends jraphical.Module

  { v4: createId }                   = require 'node-uuid'
  { Relationship }                   = jraphical
  { secure, signature, daisy, dash } = require 'bongo'

  JAccount             = require '../account'
  JSession             = require '../session'
  JInvitation          = require '../invitation'
  JName                = require '../name'
  JGroup               = require '../group'
  JLog                 = require '../log'
  ComputeProvider      = require '../computeproviders/computeprovider'
  Tracker              = require '../tracker'
  Payment              = require '../payment'

  @bannedUserList = ['abrt', 'amykhailov', 'apache', 'about', 'visa', 'shared-',
                     'cthorn', 'daemon', 'dbus', 'dyasar', 'ec2-user', 'http',
                     'games', 'ggoksel', 'gopher', 'haldaemon', 'halt', 'mail',
                     'nfsnobody', 'nginx', 'nobody', 'node', 'operator', 'https',
                     'root', 'rpcuser', 'saslauth', 'shutdown', 'sinanlocal',
                     'sshd', 'sync', 'tcpdump', 'uucp', 'vcsa', 'zabbix',
                     'search', 'blog', 'activity', 'guest', 'credits', 'about',
                     'kodingen', 'alias', 'backup', 'bin', 'bind', 'daemon',
                     'Debian-exim', 'dhcp', 'drweb', 'games', 'gnats', 'klog',
                     'kluser', 'libuuid', 'list', 'mhandlers-user', 'more',
                     'mysql', 'nagios', 'news', 'nobody', 'popuser', 'postgres',
                     'proxy', 'psaadm', 'psaftp', 'qmaild', 'qmaill', 'qmailp',
                     'qmailq', 'qmailr', 'qmails', 'sshd', 'statd', 'sw-cp-server',
                     'sync', 'syslog', 'tomcat', 'tomcat55', 'uucp', 'what',
                     'www-data', 'fuck', 'porn', 'p0rn', 'porno', 'fucking',
                     'fucker', 'admin', 'postfix', 'puppet', 'main', 'invite',
                     'administrator', 'members', 'register', 'activate', 'shared',
                     'groups', 'blogs', 'forums', 'topics', 'develop', 'terminal',
                     'term', 'twitter', 'facebook', 'google', 'framework', 'kite'
                     'landing', 'hello', 'dev', 'sandbox', 'latest']

  hashPassword = (value, salt) ->
    require('crypto').createHash('sha1').update(salt + value).digest('hex')

  createSalt = require 'hat'
  rack       = createSalt.rack 64

  @share()

  @trait __dirname, '../../traits/flaggable'

  @getFlagRole = -> 'owner'

  @set
    softDelete      : yes
    broadcastable   : no
    indexes         :
      username      : 'unique'
      email         : 'unique'
      sanitizedEmail: ['unique', 'sparse']
      'foreignAuth.github.foreignId'   : 'ascending'
      'foreignAuth.odesk.foreignId'    : 'ascending'
      'foreignAuth.facebook.foreignId' : 'ascending'
      'foreignAuth.google.foreignId'   : 'ascending'
      'foreignAuth.linkedin.foreignId' : 'ascending'
      'foreignAuth.twitter.foreignId'  : 'ascending'

    sharedEvents    :
      # do not share any events
      static        : []
      instance      : []
    sharedMethods   :
      # do not share any instance methods
      # instances     :
      static        :
        login                   : (signature Object, Function)
        whoami                  : (signature Function)
        logout                  : (signature Function)
        convert                 : (signature Object, Function)
        fetchUser               : (signature Function)
        setSSHKeys              : (signature [Object], Function)
        getSSHKeys              : (signature Function)
        unregister              : (signature String, Function)
        verifyByPin             : (signature Object, Function)
        changeEmail             : (signature Object, Function)
        verifyPassword          : (signature Object, Function)
        emailAvailable          : (signature String, Function)
        changePassword          : (signature String, Function)
        usernameAvailable       : (signature String, Function)
        authenticateWithOauth   : (signature Object, Function)
        isRegistrationEnabled   : (signature Function)

    schema          :
      username      :
        type        : String
        validate    : JName.validateName
        set         : (value) -> value.toLowerCase()
      oldUsername   : String
      uid           :
        type        : Number
        set         : Math.floor
      email         :
        type        : String
        validate    : JName.validateEmail
        set         : emailsanitize
      sanitizedEmail:
        type        : String
        validate    : JName.validateEmail
        set         : (value) ->
          return  unless typeof value is 'string'
          emailsanitize value, { excludeDots: yes, excludePlus: yes }
      password      : String
      salt          : String
      twofactorkey  : String
      blockedUntil  : Date
      blockedReason : String
      status        :
        type        : String
        enum        : [
          'invalid status type', [
            'unconfirmed', 'confirmed', 'blocked', 'deleted'
          ]
        ]
        default     : 'unconfirmed'
      passwordStatus:
        type        : String
        enum        : [
          'invalid password status type', [
            'needs reset', 'needs set', 'valid', 'autogenerated'
          ]
        ]
        default     : 'valid'
      registeredAt  :
        type        : Date
        default     : -> new Date
      registeredFrom:
        ip          : String
        country     : String
        region      : String
      lastLoginDate :
        type        : Date
        default     : -> new Date

      # store fields for janitor worker. see go/src/koding/db/models/user.go for more details.
      inactive      : Object

      # stores user preference for how often email should be sent.
      # see go/src/koding/db/models/user.go for more details.
      emailFrequency: Object

      onlineStatus  :
        actual      :
          type      : String
          enum      : ['invalid status', ['online', 'offline']]
          default   : 'online'
        userPreference:
          type      : String
          # enum      : ['invalid status',['online','offline','away','busy']]

      sshKeys       :
        type        : Object
        default     : []

      foreignAuth            :
        github               :
          foreignId          : String
          username           : String
          token              : String
          firstName          : String
          lastName           : String
          email              : String
          scope              : String
        odesk                :
          foreignId          : String
          token              : String
          accessTokenSecret  : String
          requestToken       : String
          requestTokenSecret : String
          profileUrl         : String
        facebook             :
          foreignId          : String
          username           : String
          token              : String
        linkedin             :
          foreignId          : String
    relationships       :
      ownAccount        :
        targetType      : JAccount
        as              : 'owner'
      leasedAccount     :
        targetType      : JAccount
        as              : 'leasor'

  sessions  = {}
  users     = {}
  guests    = {}

  @unregister = secure (client, toBeDeletedUsername, callback) ->

    { delegate } = client.connection
    { nickname } = delegate.profile

    console.log "#{nickname} requested to delete: #{toBeDeletedUsername}"

    # deleter should be registered one
    if delegate.type is 'unregistered'
      return callback new KodingError 'You are not registered!'

    # only owner and the dummy admins can delete a user
    unless toBeDeletedUsername is nickname or
           delegate.can 'administer accounts'
      return callback new KodingError 'You must confirm this action!'

    username = @createGuestUsername()

    # Adding -rm suffix to separate them from real guests
    # -rm was intentional otherwise we are exceeding the max username length
    username = "#{username}-rm"

    email = "#{username}@koding.com"
    @one { username: toBeDeletedUsername }, (err, user) ->
      return callback err  if err?

      unless user
        return callback new KodingError \
          "User not found #{toBeDeletedUsername}"


      userValues = {
        email           : email
        sanitizedEmail  : email
        status          : 'deleted'
        sshKeys         : []
        username        : username
        password        : createId()
        foreignAuth     : {}
        onlineStatus    : 'offline'
        registeredAt    : new Date 0
        lastLoginDate   : new Date 0
        passwordStatus  : 'autogenerated'
        emailFrequency  : {}
      }
      modifier = { $set: userValues, $unset: { oldUsername: 1 } }
      # update the user with empty data

      user.update modifier, updateUnregisteredUserAccount({
        user, username, toBeDeletedUsername, client
      }, callback)


  @isRegistrationEnabled = (callback) ->

    JRegistrationPreferences = require '../registrationpreferences'
    JRegistrationPreferences.one {}, (err, prefs) ->
      callback err? or prefs?.isRegistrationEnabled or no


  @authenticateClient: (clientId, callback) ->

    logError = (message, rest...) ->
      console.error "[JUser::authenticateClient] #{message}", rest...

    logout = (reason, clientId, callback) =>

      @logout clientId, (err) ->
        logError reason, clientId
        callback new KodingError reason

    # Let's try to lookup provided session first
    JSession.one { clientId }, (err, session) ->

      if err

        # This is a very rare state here
        logError 'error finding session', { err, clientId }
        callback new KodingError err

      else unless session?

        # We couldn't find the session with given token
        # so we are creating a new one now.
        JSession.createSession (err, { session, account }) ->

          if err?
            logError 'failed to create session', { err }
            callback err
          else

            # Voila session created and sent back, scenario #1
            callback null, { session, account }

      else

        # So we have a session, let's check it out if its a valid one
        checkSessionValidity { session, logout, clientId }, callback


  @getHash = getHash = (value) ->

    require('crypto').createHash('md5').update(value.toLowerCase()).digest('hex')


  @whoami = secure ({ connection:{ delegate } }, callback) -> callback null, delegate


  @getBlockedMessage = (toDate) ->

    return """
      This account has been put on suspension due to a violation of our acceptable use policy. The ban will be in effect until <b>#{toDate}.</b><br><br>

      If you have any questions, please email <a class="ban" href='mailto:ban@koding.com'>ban@koding.com</a> and allow 2-3 business days for a reply. Even though your account is banned, all your data is safe.<br><br>

      Please note, repeated violations of our acceptable use policy will result in the permanent deletion of your account.<br><br>

      Team Koding
    """


  checkBlockedStatus = (user, callback) ->

    return callback null  if user.status isnt 'blocked'

    if user.blockedUntil and user.blockedUntil > new Date
      toDate    = user.blockedUntil.toUTCString()
      message   = JUser.getBlockedMessage toDate
      callback new KodingError message

    else
      user.unblock callback


  @normalizeLoginId = (loginId, callback) ->

    if /@/.test loginId
      email = emailsanitize loginId
      JUser.someData { email }, { username: 1 }, (err, cursor) ->
        return callback err  if err

        cursor.nextObject (err, data) ->
          return callback err  if err?
          return callback new KodingError 'Unrecognized email'  unless data?

          callback null, data.username
    else
      process.nextTick -> callback null, loginId


  @login$ = secure (client, credentials, callback) ->

    { sessionToken : clientId, connection } = client
    @login clientId, credentials, (err, response) ->
      return callback err  if err
      connection.delegate = response.account
      callback null, response


  fetchSession = (options, queue, callback, fetchData) ->

    { clientId, username } = options

    # fetch session of the current requester
    JSession.fetchSession clientId, (err, { session: fetchedSession }) ->
      return callback err  if err

      session = fetchedSession
      unless session
        console.error "login: session not found #{username}"
        return callback new KodingError 'Couldn\'t restore your session!'

      fetchData session

      queue.next()


  validateLoginCredentials = (options, queue, callback, fetchData) ->

    { username, password, tfcode } = options

    # check credential validity
    JUser.one { username }, (err, user) ->
      return logAndReturnLoginError username, err.message, callback if err
      fetchData user

      # if user not found it means we dont know about given username
      unless user?
        return logAndReturnLoginError username, 'Unknown user name', callback

      # if password is autogenerated return error
      if user.getAt('passwordStatus') is 'needs reset'
        return logAndReturnLoginError username, \
          'You should reset your password in order to continue!', callback

      # check if provided password is correct
      unless user.checkPassword password
        return logAndReturnLoginError username, 'Access denied!', callback

      # check if user is using 2factor auth and provided key is ok
      if !!(user.getAt 'twofactorkey')

        unless tfcode
          return callback new KodingError \
            'TwoFactor auth Enabled', 'VERIFICATION_CODE_NEEDED'

        unless user.check2FactorAuth tfcode
          return logAndReturnLoginError username, 'Access denied!', callback

      # if everything is fine, just continue
      queue.next()


  fetchInvitationByCode = (invitationToken, queue, callback, fetchData) ->

    # if we dont have an invitation code, do not continue
    return queue.next()  unless invitationToken

    JInvitation = require '../invitation'
    JInvitation.byCode invitationToken, (err, invitation) ->
      return callback err  if err
      return callback new KodingError 'invitation is not valid'  unless invitation
      fetchData invitation
      queue.next()


  fetchInvitationByData = (options, queue, callback, fetchData) ->

    { user, groupName, invitationToken } = options
    # check if user has pending invitation
    return queue.next()  if invitationToken

    selector = { email: user.email, groupName }
    JInvitation = require '../invitation'
    JInvitation.one selector, {}, (err, invitation) ->
      fetchData invitation  if invitation
      queue.next()


  @login = (clientId, credentials, callback) ->

    { username: loginId, password, groupIsBeingCreated
      groupName, tfcode, invitationToken } = credentials

    user                  = null
    session               = null
    account               = null
    username              = null
    groupName            ?= 'koding'
    invitation            = null
    bruteForceControlData = {}

    queue = [

      =>
        @normalizeLoginId loginId, (err, username_) ->
          return callback err  if err
          username = username_
          queue.next()

      ->
        fetchSession {
          clientId, username
        }, queue, callback, (session_) ->
          session = session_

          bruteForceControlData =
            ip        : session.clientIP
            username  : username

      ->
        # todo add alert support(mail, log etc)
        JLog.checkLoginBruteForce bruteForceControlData, (res) ->
          unless res
            return callback new KodingError \
              "Your login access is blocked for #{JLog.timeLimit()} minutes."

          queue.next()

      ->
        validateLoginCredentials {
          username, password, tfcode
        }, queue, callback, (user_) -> user = user_

      ->
        # fetch account of the user, we will use it later
        JAccount.one { 'profile.nickname' : username }, (err, account_) ->
          return callback new KodingError 'couldn\'t find account!'  if err
          account = account_
          queue.next()

      ->
        # check if user can access to group
        #
        # there can be two cases here
        # # user is member, check validity
        # # user is not member, and trying to access with invitationToken
        # both should succeed
        fetchInvitationByCode invitationToken, queue, callback, (invitation_) ->
          invitation = invitation_

      ->
        fetchInvitationByData {
          user, groupName, invitationToken
        }, queue, callback, (invitation_) -> invitation = invitation_

      =>
        @addToGroupByInvitation {
          groupName, groupIsBeingCreated, account, user, invitation
        }, queue, callback

      ->
        return queue.next()  if groupIsBeingCreated
        # we are sure that user can access to the group, set group name into
        # cookie while logging in
        session.update { $set : { groupName } }, (err) ->
          return callback err  if err
          queue.next()

      ->
        # continue login
        afterLogin user, clientId, session, (err, response) ->
          callback err, response
          queue.next()  unless err

    ]

    daisy queue


  @verifyPassword = secure (client, options, callback) ->

    { password, email }           = options
    { connection : { delegate } } = client

    email = emailsanitize email  if email

    # handles error and decide to invalidate pin or not
    # depending on email and user variables
    handleError = (err, user) ->
      if email and user
        # when email and user is set, we need to invalidate verification token
        params =
          email     : email
          action    : 'update-email'
          username  : user.username
        JVerificationToken = require '../verificationtoken'
        JVerificationToken.invalidatePin params, (err) ->
          return console.error 'Pin invalidation error occurred', err  if err
      callback err, no

    # fetch user for invalidating created token
    @fetchUser client, (err, user) ->
      return handleError err  if err

      if not password or password is ''
        return handleError new KodingError('Password cannot be empty!'), user

      confirmed = user.getAt('password') is hashPassword password, user.getAt('salt')
      return callback null, yes  if confirmed

      return handleError null, user


  verifyByPin: (options, callback) ->

    if (@getAt 'status') is 'confirmed'
      return callback null

    JVerificationToken = require '../verificationtoken'

    { pin, resendIfExists } = options

    email    = @getAt 'email'
    username = @getAt 'username'

    options  = {
      user   : this
      action : 'verify-account'
      resendIfExists, pin, username, email
    }

    unless pin?
      JVerificationToken.requestNewPin options, (err) -> callback err

    else
      JVerificationToken.confirmByPin options, (err, confirmed) =>

        if err
          callback err
        else if confirmed
          @confirmEmail callback
        else
          callback new KodingError 'PIN is not confirmed.'


  @verifyByPin = secure (client, options, callback) ->

    account = client.connection.delegate
    account.fetchUser (err, user) ->

      return callback new Error 'User not found'  unless user

      user.verifyByPin options, callback


  @addToGroupByInvitation = (options, queue, callback) ->

    { groupName, groupIsBeingCreated, account, user, invitation } = options

    return queue.next()  if groupIsBeingCreated
    # check for membership
    JGroup.one { slug: groupName }, (err, group) ->

      return callback new KodingError err                   if err
      return callback new KodingError 'group doesnt exist'  if not group

      group.isMember account, (err, isMember) ->
        return callback err  if err
        return queue.next()  if isMember # if user is already member, we can continue

        # addGroup will check all prerequistes about joining to a group
        JUser.addToGroup account, groupName, user.email, invitation, (err) ->
          return callback err  if err
          return queue.next()


  redeemInvitation = (options, callback) ->

    { account, invitation, slug, email } = options

    return invitation.accept account, callback  if invitation

    JInvitation.one { email, groupName : slug }, (err, invitation_) ->
      # if we got error or invitation doesnt exist, just return
      return callback null if err or not invitation_
      return invitation_.accept account, callback


  # check if user's email domain is in allowed domains
  checkWithDomain = (groupName, email, callback) ->
    JGroup.one { slug: groupName }, (err, group) ->
      return callback err  if err
      # yes weird, but we are creating user before creating group
      return callback null, { isEligible: yes } if not group

      isAllowed = group.isInAllowedDomain email
      return callback new KodingError 'Your email domain is not in allowed \
        domains for this group'  unless isAllowed

      return callback null, { isEligible: yes }


  checkSessionValidity = (options, callback) ->

    { session, logout, clientId } = options
    { username } = session

    unless username?

      # A session without a username is nothing, let's kill it
      # and logout the user, this is also a rare condition
      logout 'no username found', clientId, callback

      return

    # If we are dealing with a guest session we know that we need to
    # use fake guest user

    if /^guest-/.test username
      JUser.fetchGuestUser (err, response) ->
        return logout 'error fetching guest account'  if err

        { account } = response
        return logout 'guest account not found'  if not response?.account

        account.profile.nickname = username

        return callback null, { account, session }

      return

    JUser.one { username }, (err, user) ->

      if err?

        logout 'error finding user with username', clientId, callback

      else unless user?

        logout "no user found with #{username} and sessionId", clientId, callback

      else

        context = { group: session?.groupName ? 'koding' }

        user.fetchAccount context, (err, account) ->

          if err?
            logout 'error fetching account', clientId, callback

          else

            # A valid session, a valid user attached to
            # it voila, scenario #2
            callback null, { session, account }


  updateUnregisteredUserAccount = (options, callback) ->

    { username : usernameAfterDelete, toBeDeletedUsername, user, client } = options

    return (err, docs) ->
      return callback err  if err?

      accountValues = {
        type                      : 'deleted'
        skillTags                 : []
        ircNickame                : ''
        globalFlags               : ['deleted']
        locationTags              : []
        onlineStatus              : 'offline'
        'profile.about'           : ''
        'profile.hash'            : getHash createId()
        'profile.avatar'          : ''
        'profile.nickname'        : usernameAfterDelete
        'profile.lastName'        : 'koding user'
        'profile.firstName'       : 'a former'
        'profile.experience'      : ''
        'profile.experiencePoints': 0
        'profile.lastStatusUpdate': ''
      }

      params = { 'profile.nickname' : toBeDeletedUsername }
      JAccount.one params, (err, account) ->
        return callback err  if err?

        unless account
          return callback new KodingError \
            "Account not found #{toBeDeletedUsername}"

        # update the account to be deleted with empty data
        account.update { $set: accountValues }, (err) ->
          return callback err  if err?
          JName.release toBeDeletedUsername, (err) ->
            return callback err  if err?
            JAccount.emit 'UsernameChanged', {
              oldUsername    : toBeDeletedUsername
              isRegistration : false
              username       : usernameAfterDelete
            }

            user.unlinkOAuths ->

              Payment = require '../payment'

              deletedClient = { connection: { delegate: account } }

              Payment.deleteAccount deletedClient, (err) ->

                account.leaveFromAllGroups client, ->

                  JUser.logout deletedClient, callback


  validateConvertInput = (userFormData, client) ->

    { username
      password
      passwordConfirm }         = userFormData
    { connection }              = client
    { delegate : account }      = connection

    # only unregistered accounts can be "converted"
    if account.type is 'registered'
      return new KodingError 'This account is already registered.'

    if /^guest-/.test username
      return new KodingError 'Reserved username!'

    if username is 'guestuser'
      return new KodingError 'Reserved username: \'guestuser\'!'

    if password isnt passwordConfirm
      return new KodingError 'Passwords must match!'

    return null


  logAndReturnLoginError = (username, error, callback) ->

    JLog.log { type: 'login', username: username, success: no }, ->
      callback new KodingError error


  checkUserStatus = (user, account, callback) ->

    if user.status is 'unconfirmed' and KONFIG.emailConfirmationCheckerWorker.enabled
      error = new KodingError 'You should confirm your email address'
      error.code = 403
      error.data or= {}
      error.data.name = account.profile.firstName or account.profile.nickname
      error.data.nickname = account.profile.nickname
      return callback error

    return callback null


  checkLoginConstraints = (user, account, callback) ->
    checkBlockedStatus user, (err) ->
      return callback err  if err
      checkUserStatus user, account, callback


  updateUserPasswordStatus = (user, callback) ->
    # let user log in for the first time, than set password status
    # as 'needs reset'
    if user.passwordStatus is 'needs set'
      user.update { $set : { passwordStatus : 'needs reset' } }, callback
    else
      callback null


  afterLogin = (user, clientId, session, callback) ->

    { username }      = user

    account           = null
    replacementToken  = null

    queue = [

      ->
        # fetching account, will be used to check login constraints of user
        user.fetchOwnAccount (err, account_) ->
          return callback err  if err
          account = account_
          queue.next()

      ->
        # checking login constraints
        checkLoginConstraints user, account, (err) ->
          return callback err  if err
          queue.next()

      ->
        # updating user passwordStatus if necessary
        updateUserPasswordStatus user, (err) ->
          return callback err  if err
          replacementToken = createId()
          queue.next()

      ->
        # updating session data after login
        sessionUpdateOptions =
          $set            :
            username      : username
            clientId      : replacementToken
            lastLoginDate : lastLoginDate = new Date
          $unset          :
            guestId       : 1

        guestUsername = session.username

        session.update sessionUpdateOptions, (err) ->
          return callback err  if err

          Tracker.identify username, { lastLoginDate }
          Tracker.alias guestUsername, username

          queue.next()

      ->
        # updating user data after login
        userUpdateData = { lastLoginDate : new Date }

        if session.foreignAuth
          { foreignAuth }            = user
          foreignAuth              or= {}
          foreignAuth                = extend foreignAuth, session.foreignAuth
          userUpdateData.foreignAuth = foreignAuth

        userUpdateOptions =
          $set        : userUpdateData
          $unset      :
            inactive  : 1

        user.update userUpdateOptions, (err) ->
          return callback err  if err

          # This should be called after login and this
          # is not correct place to do it, FIXME GG
          # p.s. we could do that in workers
          account.updateCounts()

          if foreignAuth
            providers = {}
            Object.keys(foreignAuth).forEach (provider) ->
              providers[provider] = yes

            Tracker.identify user.username, { foreignAuth: providers }

          JLog.log { type: 'login', username , success: yes }
          queue.next()

      ->
        JUser.clearOauthFromSession session, ->
          callback null, { account, replacementToken, returnUrl: session.returnUrl }

          Tracker.track username, { subject : Tracker.types.LOGGED_IN }
          queue.next()

    ]

    daisy queue


  @logout = secure (client, callback) ->

    if 'string' is typeof client
      sessionToken = client
    else
      { sessionToken } = client
      delete client.connection.delegate
      delete client.sessionToken

    # if sessionToken doesnt exist, safe to return
    return callback null unless sessionToken

    JSession.remove { clientId: sessionToken }, callback


  @verifyEnrollmentEligibility = (options, callback) ->

    { email, invitationToken, groupName } = options

    # this is legacy but still in use, just checks if registeration is enabled or not
    JRegistrationPreferences = require '../registrationpreferences'
    JInvitation              = require '../invitation'
    JRegistrationPreferences.one {}, (err, prefs) ->

      return callback err  if err
      unless prefs.isRegistrationEnabled
        return callback new Error 'Registration is currently disabled!'

      # check if email domain is in allowed domains
      return checkWithDomain groupName, email, callback  unless invitationToken

      JInvitation.byCode invitationToken, (err, invitation) ->
        # check if invitation exists
        if err or not invitation?
          return callback new KodingError 'Invalid invitation code!'

        # check if invitation is valid
        if invitation.isValid() and  invitation.groupName is groupName
          return callback null, { isEligible: yes, invitation }

        # last resort, check if email domain is under allowed domains
        return checkWithDomain groupName, email, callback


  @addToGroup = (account, slug, email, invitation, callback) ->

    options = { email: email, groupName: slug }
    options.invitationToken = invitation.code if invitation?.code

    JUser.verifyEnrollmentEligibility options, (err, res) ->
      return callback err  if err
      return callback new KodingError 'malformed response' if not res
      return callback new KodingError 'can not join to group' if not res.isEligible

      # fetch group that we are gonna add account in
      JGroup.one { slug }, (err, group) ->
        return callback err   if err
        return callback null  if not group

        roles = ['member']
        roles.push invitation.role  if invitation?.role
        roles = uniq roles

        group.approveMember account, roles, (err) ->
          return callback err  if err

          # do not forget to redeem invitation
          redeemInvitation {
            account, invitation, slug, email
          }, callback


  @addToGroups = (account, slugs, email, invitation, callback) ->

    slugs.push invitation.groupName if invitation?.groupName
    slugs = uniq slugs # clean up slugs
    queue = slugs.map (slug) => =>
      @addToGroup account, slug, email, invitation, (err) ->
        return callback err  if err
        queue.fin()

    dash queue, callback


  @createGuestUsername = -> "guest-#{rack()}"


  @fetchGuestUser = (callback) ->

    username      = @createGuestUsername()

    account = new JAccount()
    account.profile = { nickname: username }
    account.type = 'unregistered'

    callback null, { account, replacementToken: createId() }


  @createUser = (userInfo, callback) ->

    { username, email, password, passwordStatus,
      firstName, lastName, foreignAuth, silence, emailFrequency } = userInfo

    email = emailsanitize email
    sanitizedEmail = emailsanitize email, { excludeDots: yes, excludePlus: yes }

    emailFrequencyDefaults = {
      global         : on
      daily          : on
      privateMessage : on
      followActions  : off
      comment        : on
      likeActivities : off
      groupInvite    : on
      groupRequest   : on
      groupApproved  : on
      groupJoined    : on
      groupLeft      : off
      mention        : on
      marketing      : on
    }

    # _.defaults doesnt handle undefined, extend handles correctly
    emailFrequency = extend emailFrequencyDefaults, emailFrequency

    slug =
      slug            : username
      constructorName : 'JUser'
      usedAsPath      : 'username'
      collectionName  : 'jUsers'

    JName.claim username, [slug], 'JUser', (err) ->

      return callback err  if err

      salt = createSalt()
      user = new JUser {
        username
        email
        sanitizedEmail
        salt
        password         : hashPassword password, salt
        passwordStatus   : passwordStatus or 'valid'
        emailFrequency   : emailFrequency
      }

      user.foreignAuth = foreignAuth  if foreignAuth

      user.save (err) ->

        return  if err
          if err.code is 11000
          then callback new KodingError "Sorry, \"#{email}\" is already in use!"
          else callback err

        account      = new JAccount
          profile    : {
            nickname : username
            hash     : getHash email
            firstName
            lastName
          }

        account.save (err) ->

          if err then callback err
          else user.addOwnAccount account, (err) ->
            if err then callback err
            else callback null, user, account


  @fetchUserByProvider = (provider, session, callback) ->

    { foreignAuth } = session
    unless foreignAuth?[provider]?.foreignId
      return callback new KodingError "No foreignAuth:#{provider} info in session"

    query                                      = {}
    query["foreignAuth.#{provider}.foreignId"] = foreignAuth[provider].foreignId

    JUser.one query, callback


  @authenticateWithOauth = secure (client, resp, callback) ->

    { isUserLoggedIn, provider } = resp
    { sessionToken }             = client

    JSession.one { clientId: sessionToken }, (err, session) =>
      return callback new KodingError err  if err

      unless session
        { connection: { delegate: { profile: { nickname } } } } = client
        console.error 'authenticateWithOauth: session not found', nickname

        return callback new KodingError 'Couldn\'t restore your session!'

      kallback = (err, resp = {}) ->
        { account, replacementToken, returnUrl } = resp
        callback err, {
          isNewUser : false
          userInfo  : null
          account
          replacementToken
          returnUrl
        }

      @fetchUserByProvider provider, session, (err, user) =>

        return callback new KodingError err.message  if err

        if isUserLoggedIn
          if user and user.username isnt client.connection.delegate.profile.nickname
            @clearOauthFromSession session, ->
              callback new KodingError '''
                Account is already linked with another user.
              '''
          else
            @fetchUser client, (err, user) =>
              return callback new KodingError err.message  if err
              @persistOauthInfo user.username, sessionToken, kallback
        else
          if user
            afterLogin user, sessionToken, session, kallback
          else
            info = session.foreignAuth[provider]
            { returnUrl } = session
            { username, email, firstName, lastName, scope } = info
            callback null, {
              isNewUser : true,
              userInfo  : { username, email, firstName, lastName, scope }
              returnUrl
            }


  @validateAll = (userFormData, callback) ->

    Validator  = require './validators'
    validator  = new Validator

    isError    = no
    errors     = {}
    queue      = []

    (key for key of validator).forEach (field) =>

      queue.push => validator[field].call this, userFormData, (err) ->

        if err?
          errors[field] = err
          isError = yes

        queue.fin()

    dash queue, ->

      callback if isError
        { message: 'Errors were encountered during validation', errors }
      else null


  @changeEmailByUsername = (options, callback) ->

    { account, oldUsername, email } = options
    # prevent from leading and trailing spaces
    email = emailsanitize email
    @update { username: oldUsername }, { $set: { email } }, (err, res) ->
      return callback err  if err
      account.profile.hash = getHash email
      account.save (err) -> console.error if err
      callback null


  @changeUsernameByAccount = (options, callback) ->

    { account, username, clientId, isRegistration, groupName } = options
    account.changeUsername { username, isRegistration }, (err) ->
      return callback err   if err?
      return callback null  unless clientId?
      newToken = createId()
      JSession.one { clientId }, (err, session) ->
        if err?
          return callback new KodingError 'Could not update your session'

        if session?
          session.update { $set: { clientId: newToken, username, groupName } }, (err) ->
            return callback err  if err?
            callback null, newToken
        else
          callback new KodingError 'Session not found!'


  @removeFromGuestsGroup = (account, callback) ->

    JGroup.one { slug: 'guests' }, (err, guestsGroup) ->
      return callback err  if err?
      return callback new KodingError 'Guests group not found!'  unless guestsGroup?
      guestsGroup.removeMember account, callback


  createGroupStack = (account, groupName, callback) ->

    _client =
      connection :
        delegate : account
      context    :
        group    : groupName

    ComputeProvider.createGroupStack _client, (err) ->
      if err?
        console.warn "Failed to create group stack for #{account.profile.nickname}:", err

      # We are not returning error here on purpose, even stack template
      # not created for a user we don't want to break registration process
      # at all ~ GG
      callback()


  verifyUser = (options, callback) ->

    { slug
      email
      recaptcha
      userFormData
      foreignAuthType } = options

    queue = [

      ->
        # verifying recaptcha if enabled
        return queue.next()  unless KONFIG.recaptcha.enabled

        JUser.verifyRecaptcha recaptcha, { foreignAuthType, slug }, (err) ->
          return callback err  if err
          queue.next()

      ->
        JUser.validateAll userFormData, (err) ->
          return callback err  if err
          queue.next()

      ->
        JUser.emailAvailable email, (err, res) ->
          if err
            return callback new KodingError 'Something went wrong'

          if res is no
            return callback new KodingError 'Email is already in use!'

          queue.next()

      -> callback null

    ]

    daisy queue


  verifyEnrollmentEligibility = (options, callback) ->

    { email, client, invitationToken } = options

    # check if user can register to regarding group
    _options =
      email           : email
      groupName       : client.context.group
      invitationToken : invitationToken

    JUser.verifyEnrollmentEligibility _options, (err, res) ->
      return callback err  if err

      { isEligible, invitation } = res

      if not isEligible
        return callback new Error "you can not register to #{client.context.group}"

      callback null, invitation


  createUser = (options, callback) ->

    { userInfo } = options

    # creating a new user
    JUser.createUser userInfo, (err, user, account) ->
      return callback err  if err

      unless user? and account?
        return callback new KodingError 'Failed to create user!'

      callback null, { user, account }


  updateUserInfo = (options, callback) ->

    { user, ip, country, region, username,
      client, account, clientId, password } = options

    newToken = null

    queue = [

      ->
        # updating user's location related info
        return queue.next()  unless ip? and country? and region?

        locationModifier =
          $set                       :
            'registeredFrom.ip'      : ip
            'registeredFrom.region'  : region
            'registeredFrom.country' : country

        user.update locationModifier, ->
          queue.next()

      ->
        JUser.persistOauthInfo username, client.sessionToken, (err) ->
          return callback err  if err
          queue.next()

      ->
        return queue.next()  unless username?

        _options =
          account        : account
          username       : username
          clientId       : clientId
          groupName      : client.context.group
          isRegistration : yes

        JUser.changeUsernameByAccount _options, (err, newToken_) ->
          return callback err  if err
          newToken = newToken_
          queue.next()

      ->
        user.setPassword password, (err) ->
          return callback err  if err
          queue.next()

      -> callback null, newToken

    ]

    daisy queue


  updateAccountInfo = (options, callback) ->

    { account, referrer, username } = options

    queue = [

      ->
        account.update { $set: { type: 'registered' } }, (err) ->
          return callback err  if err?
          queue.next()

      ->
        account.createSocialApiId (err) ->
          return callback err  if err
          queue.next()

      ->
        # setting referrer
        return queue.next()  unless referrer

        if username is referrer
          console.error "User (#{username}) tried to refer themself."
          return queue.next()

        JUser.count { username: referrer }, (err, count) ->
          if err? or count < 1
            console.error 'Provided referrer not valid:', err
            return queue.next()

          account.update { $set: { referrerUsername: referrer } }, (err) ->

            if err?
            then console.error err
            else console.log "#{referrer} referred #{username}"

            queue.next()

      -> callback null

    ]

    daisy queue


  createDefaultStackForKodingGroup = (options, callback) ->

    { account } = options

    # create default stack for koding group, when a user joins this is only
    # required for koding group, not neeed for other teams
    _client =
      connection :
        delegate : account
      context    :
        group    : 'koding'

    ComputeProvider.createGroupStack _client, (err) ->
      if err?
        console.warn "Failed to create group stack
                      for #{account.profile.nickname}:#{err}"

      # We are not returning error here on purpose, even stack template
      # not created for a user we don't want to break registration process
      # at all ~ GG
      callback null


  confirmAccountIfNeeded = (options, callback) ->

    { user, email, username, group } = options

    if KONFIG.autoConfirmAccounts or group isnt 'koding'
      user.confirmEmail (err) ->
        console.warn err  if err?
        return callback err

    else
      _options =
        email    : email
        action   : 'verify-account'
        username : username

      JVerificationToken = require '../verificationtoken'
      JVerificationToken.createNewPin _options, (err, confirmation) ->
        console.warn 'Failed to send verification token:', err  if err
        callback err, confirmation?.pin


  validateConvert = (options, callback) ->

    { client, userFormData, foreignAuthType } = options
    { slug, email, invitationToken, recaptcha } = userFormData

    invitation = null

    queue = [

      ->
        params = { slug, email, recaptcha, userFormData, foreignAuthType }
        verifyUser params, (err) ->
          return callback err  if err
          queue.next()

      ->
        params = { email, client, invitationToken }
        verifyEnrollmentEligibility params, (err, invitation_) ->
          return callback err  if err
          invitation = invitation_
          queue.next()


      -> callback null, { invitation }

    ]

    daisy queue


  processConvert = (options, callback) ->

    { ip, country, region, client, invitation, userFormData } = options
    { sessionToken : clientId } = client
    { referrer, email, username, password,
    emailFrequency, firstName, lastName } = userFormData

    user     = null
    error    = null
    account  = null
    newToken = null

    queue = [

      ->
        userInfo = {
          email, username, password, lastName, firstName, emailFrequency
        }
        createUser { userInfo }, (err, data) ->
          return callback err  if err
          { user, account } = data
          queue.next()

      ->
        params = {
          user, ip, country, region, username
          password, clientId, account, client
        }
        updateUserInfo params, (err, newToken_) ->
          return callback err  if err
          newToken = newToken_
          queue.next()

      ->
        updateAccountInfo { account, referrer, username }, (err) ->
          return callback err  if err
          queue.next()

      ->
        groupNames = [client.context.group, 'koding']

        JUser.addToGroups account, groupNames, user.email, invitation, (err) ->
          error = err
          queue.next()

      ->
        createDefaultStackForKodingGroup { account }, (err) ->
          return callback err  if err
          queue.next()

      # passing "error" variable to be used as an argument in the callback func.
      # that is being called after registration process is completed.
      -> callback null, { error, newToken, user, account }

    ]

    daisy queue



  @convert = secure (client, userFormData, callback) ->

    { slug, email, agree, username, lastName, referrer,
      password, firstName, recaptcha, emailFrequency,
      invitationToken, passwordConfirm } = userFormData

    { clientIP, connection }    = client
    { delegate : account }      = connection
    { nickname : oldUsername }  = account.profile

    # if firstname is not received use username as firstname
    userFormData.firstName = username  unless firstName
    userFormData.lastName  = ''        unless lastName

    email = userFormData.email = emailsanitize email

    if error = validateConvertInput userFormData, client
      return callback error

    if clientIP
      { ip, country, region } = Regions.findLocation clientIP

    pin              = null
    user             = null
    error            = null
    newToken         = null
    invitation       = null
    foreignAuthType  = null
    subscription     = null

    queue = [

      =>
        @extractOauthFromSession client.sessionToken, (err, foreignAuthInfo) ->
          if err
            console.log 'Error while getting oauth data from session', err
            return queue.next()

          return queue.next()  unless foreignAuthInfo

          # Password is not required for GitHub users since they are authorized via GitHub.
          # To prevent having the same password for all GitHub users since it may be
          # a security hole, let's auto generate it if it's not provided in request
          unless password
            password        = userFormData.password        = createId()
            passwordConfirm = userFormData.passwordConfirm = password

          queue.next()

      ->
        validateConvert { client, userFormData, foreignAuthType }, (err, data) ->
          return callback err  if err
          { invitation } = data
          queue.next()

      ->
        params = { ip, country, region, client, invitation, userFormData }
        processConvert params, (err, data) ->
          return callback err  if err
          { error, newToken, user, account } = data
          queue.next()

      ->
        JUser.emit 'UserRegistered', { user, account }
        queue.next()

      ->
        # Auto confirm accounts for development environment or Teams ~ GG
        options = { group : client.context.group, user, email, username }
        confirmAccountIfNeeded options, (err, pin_) ->
          return callback err  if err
          pin = pin_
          queue.next()

      ->
        date = new Date 0
        subscription =
          accountId          : account.getId()
          planTitle          : 'free'
          planInterval       : 'month'
          state              : 'active'
          provider           : 'koding'
          expiredAt          : date
          canceledAt         : date
          currentPeriodStart : date
          currentPeriodEnd   : date

        queue.next()

      ->
        jwtToken = JUser.createJWT { username }

        { status, lastLoginDate } = user
        { createdAt } = account.meta

        sshKeysCount = user.sshKeys.length

        emailFrequency =
          global       : user.emailFrequency.global
          marketing    : user.emailFrequency.marketing

        traits = {
          email
          createdAt
          lastLoginDate
          status

          firstName
          lastName

          subscription
          sshKeysCount
          emailFrequency

          pin
          jwtToken
        }

        Tracker.identify username, traits
        Tracker.alias oldUsername, username

        queue.next()

      ->
        subject             = Tracker.types.START_REGISTER
        { username, email } = user

        opts = { pin, email, group: client.context.group }
        Tracker.track username, { to : email, subject }, opts

        queue.next()

      ->
        # don't block register
        callback error, { account, newToken, user }
        queue.next()

      ->
        SiftScience = require '../siftscience'
        SiftScience.createAccount client, referrer, ->

    ]

    daisy queue


  @createJWT: (data) ->
    { secret, confirmExpiresInMinutes } = KONFIG.jwt

    jwt = require 'jsonwebtoken'

    # uses 'HS256' as default for signing
    options =
      expiresInMinutes : confirmExpiresInMinutes

    return jwt.sign data, secret, options

  @removeUnsubscription:({ email }, callback) ->

    JUnsubscribedMail = require '../unsubscribedmail'
    JUnsubscribedMail.one { email }, (err, unsubscribed) ->
      return callback err  if err or not unsubscribed
      unsubscribed.remove callback


  @grantInitialInvitations = (username) ->
    JInvitation.grant { 'profile.nickname': username }, 3, (err) ->
      console.log 'An error granting invitations', err if err


  @fetchUser = secure (client, callback) ->

    JSession.one { clientId: client.sessionToken }, (err, session) ->
      return callback err  if err

      noUserError = new KodingError \
        'No user found! Not logged in or session expired'

      if not session or not session.username
        return callback noUserError

      JUser.one { username: session.username }, (err, user) ->

        if err or not user
          console.log '[JUser::fetchUser]', err  if err?
          callback noUserError
        else
          callback null, user


  @changePassword = secure (client, password, callback) ->

    @fetchUser client, (err, user) ->

      if err or not user
        return callback new KodingError \
          'Something went wrong please try again!'

      if user.getAt('password') is hashPassword password, user.getAt('salt')
        return callback new KodingError 'PasswordIsSame'

      user.changePassword password, (err) ->
        return callback err  if err

        account  = client.connection.delegate
        clientId = client.sessionToken

        account.sendNotification 'SessionHasEnded', { clientId }

        selector = { clientId: { $ne: client.sessionToken } }

        user.killSessions selector, callback


  sendChangedEmail = (username, firstName, to, type) ->

    subject = if type is 'email' then Tracker.types.CHANGED_EMAIL
    else Tracker.types.CHANGED_PASSWORD

    Tracker.track username, { to, subject }, { firstName }


  @changeEmail = secure (client, options, callback) ->

    { email } = options

    email = options.email = emailsanitize email

    account = client.connection.delegate
    account.fetchUser (err, user) =>
      return callback new KodingError 'Something went wrong please try again!' if err
      return callback new KodingError 'EmailIsSameError' if email is user.email

      @emailAvailable email, (err, res) ->
        return callback new KodingError 'Something went wrong please try again!' if err

        if res is no
          callback new KodingError 'Email is already in use!'
        else
          user.changeEmail account, options, callback


  @emailAvailable = (email, callback) ->

    unless typeof email is 'string'
      return callback new KodingError 'Not a valid email!'

    sanitizedEmail = emailsanitize email, { excludeDots: yes, excludePlus: yes }

    @count { sanitizedEmail }, (err, count) ->
      callback err, count is 0


  @getValidUsernameLengthRange = -> { minLength : 4, maxLength : 25 }


  @usernameAvailable = (username, callback) ->

    JName     = require '../name'

    username += ''
    res       =
      kodingUser : no
      forbidden  : yes

    JName.count { name: username }, (err, count) =>
      { minLength, maxLength } = JUser.getValidUsernameLengthRange()

      if err or username.length < minLength or username.length > maxLength
        callback err, res
      else
        res.kodingUser = count is 1
        res.forbidden  = username in @bannedUserList
        callback null, res


  fetchAccount: (context, rest...) -> @fetchOwnAccount rest...


  setPassword: (password, callback) ->

    salt = createSalt()
    @update {
      $set             :
        salt           : salt
        password       : hashPassword password, salt
        passwordStatus : 'valid'
    }, callback


  changePassword: (newPassword, callback) ->

    @setPassword newPassword, (err) =>
      return callback err  if err

      @fetchAccount 'koding', (err, account) =>
        return callback err  if err
        return callback new KodingError 'Account not found' unless account

        { firstName } = account.profile
        sendChangedEmail @getAt('username'), firstName, @getAt('email'), 'password'

        callback null


  changeEmail: (account, options, callback) ->

    JVerificationToken = require '../verificationtoken'

    { email, pin } = options

    email = options.email = emailsanitize email
    sanitizedEmail = emailsanitize email, { excludeDots: yes, excludePlus: yes }

    if account.type is 'unregistered'
      @update { $set: { email , sanitizedEmail } }, (err) ->
        return callback err  if err

        callback null
      return

    action = 'update-email'

    if not pin

      options = {
        email, action, user: this, resendIfExists: yes
      }

      JVerificationToken.requestNewPin options, callback

    else
      options = {
        email, action, pin, username: @getAt 'username'
      }

      JVerificationToken.confirmByPin options, (err, confirmed) =>

        return callback err  if err

        unless confirmed
          return callback new KodingError 'PIN is not confirmed.'

        oldEmail = @getAt 'email'

        @update { $set: { email, sanitizedEmail } }, (err, res) =>
          return callback err  if err

          account.profile.hash = getHash email
          account.save (err) =>
            return callback err  if err

            { firstName } = account.profile

            # send EmailChanged event
            @constructor.emit 'EmailChanged', {
              username: @getAt('username')
              oldEmail: oldEmail
              newEmail: email
            }

            sendChangedEmail @getAt('username'), firstName, oldEmail, 'email'

            callback null

            Tracker.identify @username, { email }


  fetchHomepageView: (options, callback) ->

    { account, bongoModels } = options
    @fetchAccount 'koding', (err, account) ->
      if err then callback err
      else account.fetchHomepageView options, callback


  confirmEmail: (callback) ->

    status   = @getAt 'status'
    username = @getAt 'username'

    # for some reason status is sometimes 'undefined', so check for that
    if status? and status isnt 'unconfirmed'
      console.log "ALERT: #{username} is trying to confirm '#{status}' email"
      return callback null

    modifier = { status: 'confirmed' }

    @update { $set: modifier }, (err, res) =>
      return callback err if err
      JUser.emit 'EmailConfirmed', this

      callback null

      Tracker.identify username, modifier

      Tracker.track username, { subject: Tracker.types.FINISH_REGISTER }


  block: (blockedUntil, callback) ->

    unless blockedUntil then return callback new KodingError 'Blocking date is not defined'

    status = 'blocked'

    @update { $set: { status, blockedUntil } }, (err) =>

      return callback err if err

      JUser.emit 'UserBlocked', this

      console.log 'JUser#block JSession#remove', { @username, blockedUntil }

      # clear all of the cookies of the blocked user
      JSession.remove { username: @username }, callback

      Tracker.identify @username, { status }


  unblock: (callback) ->

    status = 'confirmed'

    op =
      $set   : { status }
      $unset : { blockedUntil: yes }

    @update op, (err) =>

      return callback err  if err

      JUser.emit 'UserUnblocked', this
      callback()

      Tracker.identify @username, { status }


  unlinkOAuths: (callback) ->

    @update { $unset: { foreignAuth:1 , foreignAuthType:1 } }, (err) =>
      return callback err  if err

      @fetchOwnAccount (err, account) ->
        return callback err  if err
        account.unstoreAll callback


  @persistOauthInfo: (username, clientId, callback) ->

    @extractOauthFromSession clientId, (err, foreignAuthInfo) =>
      return callback err   if err
      return callback null  unless foreignAuthInfo
      return callback null  unless foreignAuthInfo.session

      @saveOauthToUser foreignAuthInfo, username, (err) =>
        return callback err  if err

        do (foreignAuth = {}) ->
          { foreignAuthType } = foreignAuthInfo
          foreignAuth[foreignAuthType] = yes
          Tracker.identify username, { foreignAuth }

        @clearOauthFromSession foreignAuthInfo.session, (err) =>
          return callback err  if err

          @copyPublicOauthToAccount username, foreignAuthInfo, (err, resp = {}) ->
            return callback err  if err
            { session: { returnUrl } } = foreignAuthInfo
            resp.returnUrl = returnUrl  if returnUrl
            return callback null, resp


  @extractOauthFromSession: (clientId, callback) ->

    JSession.one { clientId: clientId }, (err, session) ->
      return callback err   if err
      return callback null  unless session

      { foreignAuth, foreignAuthType } = session
      if foreignAuth and foreignAuthType
        callback null, { foreignAuth, foreignAuthType, session }
      else
        callback null # WARNING: don't assume it's an error if there's no foreignAuth


  @saveOauthToUser: ({ foreignAuth, foreignAuthType }, username, callback) ->

    query = {}
    query["foreignAuth.#{foreignAuthType}"] = foreignAuth[foreignAuthType]

    @update { username }, { $set: query }, callback


  @clearOauthFromSession: (session, callback) ->

    session.update { $unset: { foreignAuth:1, foreignAuthType:1 } }, callback


  @copyPublicOauthToAccount: (username, { foreignAuth, foreignAuthType }, callback) ->

    JAccount.one { 'profile.nickname' : username }, (err, account) ->
      return callback err  if err

      name    = "ext|profile|#{foreignAuthType}"
      content = foreignAuth[foreignAuthType].profile
      account._store { name, content }, callback


  @setSSHKeys: secure (client, sshKeys, callback) ->

    @fetchUser client, (err, user) ->
      user.sshKeys = sshKeys
      user.save callback

      Tracker.identify user.username, { sshKeysCount: sshKeys.length }


  @getSSHKeys: secure (client, callback) ->

    @fetchUser client, (err, user) ->
      callback user.sshKeys or []


  ###*
   * Compare provided password with JUser.password
   *
   * @param {string} password
  ###
  checkPassword: (password) ->

    # hash of given password and given user's salt should match with user's password
    return @getAt('password') is hashPassword password, @getAt('salt')


  ###*
   * Compare provided verification token with time
   * based generated 2Factor code. If 2Factor not enabled returns true
   *
   * @param {string} verificationCode
  ###
  check2FactorAuth: (verificationCode) ->

    key          = @getAt 'twofactorkey'

    speakeasy    = require 'speakeasy'
    generatedKey = speakeasy.totp { key, encoding: 'base32' }

    return generatedKey is verificationCode


  ###*
   * Verify if `response` from client is valid by asking recaptcha servers.
   * Check is disabled in dev mode or when user is authenticating via `github`.
   *
   * @param {string}   response
   * @param {string}   foreignAuthType
   * @param {function} callback
  ###
  @verifyRecaptcha = (response, params, callback) ->

    { url, secret }           = KONFIG.recaptcha
    { foreignAuthType, slug } = params

    return callback null  if foreignAuthType is 'github'

    # TODO: temporarily disable recaptcha for groups
    if slug? and slug isnt 'koding'
      return callback null

    request.post url, { form: { response, secret } }, (err, res, raw) ->
      if err
        console.log "Recaptcha: err validation captcha: #{err}"

      if not err and res.statusCode is 200
        try
          if JSON.parse(raw)['success']
            return callback null
        catch e
          console.log "Recaptcha: parsing response failed. #{raw}"

      return callback new KodingError 'Captcha not valid. Please try again.'


  ###*
   * Remove session documents matching selector object.
   *
   * @param {Object} [selector={}] - JSession query selector.
   * @param {Function} - Callback.
  ###
  killSessions: (selector = {}, callback) ->

    selector.username = @username
    JSession.remove selector, callback
