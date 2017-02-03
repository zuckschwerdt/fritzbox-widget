# your router hostname
router_hostname = 'fritz.box'

# note: no need for the proxy if the server returns CORS headers
proxy = 'http://127.0.0.1:41417/'

# refresh cycle counter
cycle = 0
upstreamMaxBitRate = null
downstreamMaxBitRate = null

command: (callback) ->
  soapQuery = (endpoint, action, body) ->
    envelope = '<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body>' + body + '</s:Body></s:Envelope>'
    $.ajax
      url: proxy + 'http://' + router_hostname + ':49000' + endpoint
      method: 'POST'
      contentType: 'text/xml; charset="utf-8"'
      data: envelope
      headers:
        'SOAPAction': action
      success : (res, status, xhr) -> callback null, res
      error   : (xhr, status, err) -> callback null, xhr

  # query throughput every second
  soapQuery(
    '/igdupnp/control/WANCommonIFC1'
    'urn:schemas-upnp-org:service:WANCommonInterfaceConfig:1#GetAddonInfos'
    '<u:GetAddonInfos xmlns:u="urn:schemas-upnp-org:service:WANCommonInterfaceConfig:1" />'
  )

  # query link every minute
  if cycle % 59 == 0
    soapQuery(
      '/igdupnp/control/WANCommonIFC1'
      'urn:schemas-upnp-org:service:WANCommonInterfaceConfig:1#GetCommonLinkProperties'
      '<u:GetCommonLinkProperties xmlns:u="urn:schemas-upnp-org:service:WANCommonInterfaceConfig:1" />'
    )

  # query ip address every minute
  if cycle % 61 == 0
    soapQuery(
      '/igdupnp/control/WANIPConn1'
      'urn:schemas-upnp-org:service:WANIPConnection:1#GetExternalIPAddress'
      '<u:GetExternalIPAddress xmlns:u="urn:schemas-upnp-org:service:WANIPConnection:1" />'
    )

  cycle += 1

refreshFrequency: 1000 # ms

render: ->
  """
  <div>
    WAN <span class="info WANAccessType">-</span>
    LINK <span class="info PhysicalLinkStatus">-</span>
    IP <span class="info ExternalIPAddress">-</span>
  </div>

  <div>
    △ <span class="rate ByteSendRate">-</span> KiB/s
    <span class="total TotalBytesSent">-</span>
  </div>
  <div>
    ▽ <span class="rate ByteReceiveRate">-</span> KiB/s
    <span class="total TotalBytesReceived">-</span>
  </div>

  <div>
    UP <span class="info Layer1UpstreamMaxBitRate">-</span> MiBit/s
    DOWN <span class="info Layer1DownstreamMaxBitRate">-</span> MiBit/s
  </div>

  <div class="ErrorMsg"></div>
"""

update: (xml, domEl) ->
  toKibi = (num) ->
     Math.round(num * 10 / 1024) / 10

  toMebi = (num) ->
     Math.round(num * 10 / 1024 / 1024) / 10

  toIEC = (num) ->
    units = ['B', 'KiB','MiB','GiB','TiB','PiB','EiB','ZiB','YiB']
    s = 0
    while (num > 500)
      num /= 1024
      s += 1
    (Math.round(num * 10) / 10) + " " + units[s]

  getValue = (tagName) ->
    tag = xml.getElementsByTagName(tagName)[0]
    if tag then tag.firstChild.nodeValue else null

  displayValue = (tagName, target, transform) ->
    tag = xml.getElementsByTagName(tagName)[0]
    if tag
      value = tag.firstChild.nodeValue
      if transform
        value = transform value
      $(domEl).find(target).text(value)

  # debug: abort if something went wrong
  if not (xml instanceof XMLDocument)
    $(domEl).find('.ErrorMsg').text(JSON.stringify(xml))
    return
  # $(domEl).text((new XMLSerializer()).serializeToString(xml))

  displayValue 'NewByteSendRate', '.ByteSendRate', toKibi
  displayValue 'NewByteReceiveRate', '.ByteReceiveRate', toKibi
  displayValue 'NewTotalBytesSent', '.TotalBytesSent', toIEC
  displayValue 'NewTotalBytesReceived', '.TotalBytesReceived', toIEC
  displayValue 'NewWANAccessType', '.WANAccessType'
  displayValue 'NewLayer1UpstreamMaxBitRate', '.Layer1UpstreamMaxBitRate', toMebi
  displayValue 'NewLayer1DownstreamMaxBitRate', '.Layer1DownstreamMaxBitRate', toMebi
  displayValue 'NewPhysicalLinkStatus', '.PhysicalLinkStatus'
  displayValue 'NewExternalIPAddress', '.ExternalIPAddress'

  value = getValue 'NewLayer1UpstreamMaxBitRate'
  if value
    upstreamMaxBitRate = value
  value = getValue 'NewLayer1DownstreamMaxBitRate'
  if value
    downstreamMaxBitRate = value

  value = getValue 'NewByteSendRate'
  if value and upstreamMaxBitRate
    upstreamUtilization = Math.round(value * 5 * 8 / upstreamMaxBitRate)
    $(domEl).find('.ByteSendRate').parent().attr('class', 'utilization-' + upstreamUtilization)

  value = getValue 'NewByteReceiveRate'
  if value and downstreamMaxBitRate
    downstreamUtilization = Math.round(value * 5 * 8 / downstreamMaxBitRate)
    $(domEl).find('.ByteReceiveRate').parent().attr('class', 'utilization-' + downstreamUtilization)

style: """
  left: 100px
  bottom: 140px
  color: rgba(#fff, 0.75)
  font-family: Helvetica Neue

  div
    margin: 0
    font-weight: 100
    font-size: 16px

  .rate
    font-size: 48px
    font-weight: 300

  .total
    font-size: 32px
    font-weight: 300

  .info
    font-size: 24px
    font-weight: 300

  .utilization-0
    color: rgba(#fff, 0.25)
  .utilization-1
    color: rgba(#fff, 0.5)
  .utilization-2
    color: rgba(#fff, 0.75)
  .utilization-3
    color: rgba(#7f7, 0.75)
  .utilization-4
    color: rgba(#ff0, 0.75)
  .utilization-5
    color: rgba(#f77, 0.75)

"""