# julia -i server.jl

using Bukdu
const ServerHost = "localhost"
const ServerPort = 8080

struct WSController <: ApplicationController
    conn::Conn
end

function websocket(::WSController)
    js = """
var wsUri = "ws://$ServerHost:$ServerPort/";
var output;
var m;

function init() {
  output = document.getElementById("output");
  testWebSocket();
  m = window.mode_objects['4D'];
  console.log("m ", m)
}

function testWebSocket() {
  websocket = new WebSocket(wsUri);
  websocket.onopen = function(evt) { onOpen(evt) };
  websocket.onclose = function(evt) { onClose(evt) };
  websocket.onmessage = function(evt) { onMessage(evt) };
  websocket.onerror = function(evt) { onError(evt) };
}

function onOpen(evt) {
  println("CONNECTED");
  msg = JSON.stringify("WebSocket rocks");
  doSend(msg);
}

function onClose(evt) {
  println("DISCONNECTED");
}

function cc102(nt) {
  obj = m.leftScene;
  switch (nt.value) {
      case 0x01:
          println("0x01");
          obj.rotation.x += 0.1;
          break;
      case 0x7f:
          println("0x7f");
          obj.rotation.x -= 0.1;
          break;
  }
}

function cc103(nt) {
  obj = m.leftScene;
  switch (nt.value) {
      case 0x01:
          obj.rotation.y += 0.1;
          break;
      case 0x7f:
          obj.rotation.y -= 0.1;
          break;
  }
}

function midi_button(nt) {
  switch (nt.name) {
      case "cc102": // knob 1
          cc102(nt);
          break;
      case "cc103": // knob 2
          cc103(nt);
          break;
     default:
          break;
  }
}

function midi_callback(nt) {
  switch (nt.action) {
     case "button":
        midi_button(nt);
        break;
     default:
        break; 
  }
}

function onMessage(evt) {
  nt = JSON.parse(evt.data);
  println('<span style="color: blue;">RESPONSE: ' + JSON.stringify(nt) + '</span>');
  midi_callback(nt);
  // websocket.close();
}

function onError(evt) {
  println('<span style="color: red;">ERROR:</span> ' + evt.data);
}

function doSend(message) {
  println("SENT: " + message);
  websocket.send(message);
}

function println(message) {
  var pre = document.createElement("p");
  pre.style.wordWrap = "break-word";
  pre.innerHTML = message;
  output.appendChild(pre);
}

window.addEventListener("load", init, false);
"""
    render(JavaScript, js)
end

plug(Plug.Logger, access_log=(path=normpath(@__DIR__, "access.log"),), formatter=Plug.LoggerFormatter.datetime_message)

routes(:front) do
    get("/websocket.js", WSController, websocket)
    plug(Plug.WebSocket)
    plug(Plug.Static, at="/", from=normpath(@__DIR__))
end

Bukdu.start(ServerPort, host=ServerHost)

function midi_event(msg)
    buttons = Dict(
        0x47 => "cc102",
    )
    name = get(buttons, msg[2], "")
    value = msg[3]
    (action="button", name=name, value=value)
end

using JSON2
function midi_callback(msg)
    # @info midi_callback first(msg)
    # if 0x90 == first(msg)
    if true
        websocks = Bukdu.websockets()
        if isempty(websocks)
            @error "please visit the url in the web browser"
        else
            ws = first(websocks)
            nt = midi_event(msg)
            written = write(ws, JSON2.write(nt))
            (written, nt)
        end
    end
end


#=
julia> midi_callback(UInt8[0xb0, 0x47, 0x01])
(46, (action = "change", name = "cc102", value = 0x7f))
=#


#=
import PushInterface: RTMIDI
import .RTMIDI: rtmidi_in_create_default, rtmidi_open_port, rtmidi_in_set_callback
import .RTMIDI: destroy, EventCB, rtmidi_callback_func

device = rtmidi_in_create_default()
rtmidi_open_port(device, 1, "Ableton Push 2 User Port")
if !(device[].ok)
    @error :rtmidi_open_port "could not found ableton push 2"
    exit(1)
end

cb_ptr = @cfunction rtmidi_callback_func Cvoid (Cdouble, Ptr{Cuchar}, Ptr{EventCB})
cond = Base.AsyncCondition()
handle = Base.unsafe_convert(Ptr{Cvoid}, cond)
ecb = EventCB(handle, 0, C_NULL)
r_ecb = Ref(ecb)
rtmidi_in_set_callback(device, cb_ptr, r_ecb)
finalizer(destroy, device)


function _callback_async_loop(cond, r_ecb)
    while isopen(cond)
        wait(cond)
        msg = codeunits(unsafe_string(r_ecb[].message))
        midi_callback(msg)
    end
end

cbloop = Task() do
    _callback_async_loop(cond, r_ecb)
end
schedule(cbloop)
=#

Base.JLOptions().isinteractive==0 && wait()
