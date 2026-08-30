#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

#include <commctrl.h>
#include <vector>
#include <cstring>
#include "flutter/binary_messenger.h"
#pragma comment(lib, "comctl32.lib")

#ifndef WM_TABLET_QUERYSYSTEMGESTURESTATUS
#define WM_TABLET_QUERYSYSTEMGESTURESTATUS 0x02CC
#endif
#ifndef TABLET_DISABLE_PRESSANDHOLD
#define TABLET_DISABLE_PRESSANDHOLD 0x00000001
#endif
#ifndef TABLET_DISABLE_PENTAPFEEDBACK
#define TABLET_DISABLE_PENTAPFEEDBACK 0x00000008
#endif
#ifndef TABLET_DISABLE_PENBARRELFEEDBACK
#define TABLET_DISABLE_PENBARRELFEEDBACK 0x00000010
#endif
#ifndef TABLET_DISABLE_TOUCHUIFORCEON
#define TABLET_DISABLE_TOUCHUIFORCEON 0x00000100
#endif
#ifndef TABLET_DISABLE_TOUCHUIFORCEOFF
#define TABLET_DISABLE_TOUCHUIFORCEOFF 0x00000200
#endif
#ifndef TABLET_DISABLE_TOUCHSWITCH
#define TABLET_DISABLE_TOUCHSWITCH 0x00000400
#endif
#ifndef TABLET_DISABLE_FLICKS
#define TABLET_DISABLE_FLICKS 0x00010000
#endif
#ifndef TABLET_ENABLE_MULTITOUCHDATA
#define TABLET_ENABLE_MULTITOUCHDATA 0x01000000
#endif

#define TABLET_FLAGS_ALL_DISABLED ( \
    TABLET_DISABLE_PRESSANDHOLD | \
    TABLET_DISABLE_PENTAPFEEDBACK | \
    TABLET_DISABLE_PENBARRELFEEDBACK | \
    TABLET_DISABLE_TOUCHUIFORCEON | \
    TABLET_DISABLE_TOUCHUIFORCEOFF | \
    TABLET_DISABLE_TOUCHSWITCH | \
    TABLET_DISABLE_FLICKS | \
    TABLET_ENABLE_MULTITOUCHDATA)

extern "C" {
  struct StylusNativeState {
    bool is_contact;
    bool is_barrel_primary_pressed;
    bool is_barrel_secondary_pressed;
    bool is_inverted_eraser;
    float pressure;
    int32_t tilt_x;
    int32_t tilt_y;
    uint32_t button_count;
  };

  StylusNativeState g_stylus_state = {0};

  __declspec(dllexport) StylusNativeState* getStylusRealtimeState() {
    return &g_stylus_state;
  }

  __declspec(dllexport) uint32_t connotes_query_stylus_caps() {
    return g_stylus_state.button_count > 0 ? g_stylus_state.button_count : 2;
  }
}

// Ponteiro global para o messenger do Flutter Engine (para enviar eventos ao Dart)
static flutter::BinaryMessenger* g_messenger = nullptr;

// Envia o estado atual dos botões ao Dart via MethodChannel
static void SendStylusStateToFlutter() {
  if (!g_messenger) return;

  // Serialização manual em Standard Message Codec (formato binário simples do Flutter)
  // Monta um mapa: {"b1": bool, "b2": bool, "eraser": bool}
  std::vector<uint8_t> buffer;
  // Tipo: kMap = 13
  buffer.push_back(13);
  // Número de entradas: 3 (uint32 big-endian)
  buffer.push_back(0); buffer.push_back(0); buffer.push_back(0); buffer.push_back(3);

  auto push_bool_entry = [&](const char* key, bool value) {
    // key: kString = 7
    buffer.push_back(7);
    size_t len = strlen(key);
    buffer.push_back((uint8_t)len);
    for (size_t i = 0; i < len; i++) buffer.push_back((uint8_t)key[i]);
    // value: kTrue = 1, kFalse = 2
    buffer.push_back(value ? 1 : 2);
  };

  push_bool_entry("b1", g_stylus_state.is_barrel_primary_pressed);
  push_bool_entry("b2", g_stylus_state.is_barrel_secondary_pressed);
  push_bool_entry("eraser", g_stylus_state.is_inverted_eraser);

  auto data = std::make_unique<std::vector<uint8_t>>(std::move(buffer));
  g_messenger->Send(
    "connotes/stylus_state",
    data->data(), data->size(),
    nullptr
  );
}

static LRESULT CALLBACK FlutterChildSubclassProc(
    HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam,
    UINT_PTR uIdSubclass, DWORD_PTR dwRefData) {

  if (uMsg == WM_TABLET_QUERYSYSTEMGESTURESTATUS) {
    return TABLET_FLAGS_ALL_DISABLED;
  }

  if (uMsg == WM_POINTERDOWN || uMsg == WM_POINTERUPDATE || 
      uMsg == WM_POINTERUP || uMsg == WM_POINTERENTER || uMsg == WM_POINTERLEAVE) {
    
    POINTER_INFO pointerInfo = {0};
    uint32_t pointerId = GET_POINTERID_WPARAM(wParam);
    
    if (GetPointerInfo(pointerId, &pointerInfo)) {
      if (pointerInfo.pointerType == PT_PEN) {
        POINTER_PEN_INFO penInfo = {0};
        if (GetPointerPenInfo(pointerId, &penInfo)) {
          // Log detalhado no DebugView / Output do Visual Studio
          char debugBuf[128];
          sprintf_s(debugBuf, "[conNotes Stylus] penFlags: 0x%08X | pointerFlags: 0x%08X\n", 
                    penInfo.penFlags, penInfo.pointerInfo.pointerFlags);
          OutputDebugStringA(debugBuf);

          // Botão 1 (Inferior): PEN_FLAG_BARREL
          bool new_b1 = (penInfo.penFlags & PEN_FLAG_BARREL) != 0;
          
          // Botão 2 (Superior): PEN_FLAG_INVERTED ou mapeamento como PEN_FLAG_ERASER pelo driver da mesa
          bool new_b2 = ((penInfo.penFlags & PEN_FLAG_INVERTED) != 0) || 
                        (((penInfo.penFlags & PEN_FLAG_ERASER) != 0) && !new_b1);
          
          // Borracha física dedicada (se não for acionada em conjunto como botão lateral)
          bool new_eraser = ((penInfo.penFlags & PEN_FLAG_ERASER) != 0) && !new_b2;

          bool changed = (new_b1 != g_stylus_state.is_barrel_primary_pressed) ||
                         (new_b2 != g_stylus_state.is_barrel_secondary_pressed) ||
                         (new_eraser != g_stylus_state.is_inverted_eraser);

          g_stylus_state.is_contact = (penInfo.pointerInfo.pointerFlags & POINTER_FLAG_INCONTACT) != 0;
          g_stylus_state.is_barrel_primary_pressed = new_b1;
          g_stylus_state.is_barrel_secondary_pressed = new_b2;
          g_stylus_state.is_inverted_eraser = new_eraser;
          g_stylus_state.pressure = (float)penInfo.pressure / 1024.0f;
          g_stylus_state.tilt_x = penInfo.tiltX;
          g_stylus_state.tilt_y = penInfo.tiltY;
          g_stylus_state.button_count = 2;

          if (changed) {
            SendStylusStateToFlutter();
          }
        }
      }
    }
  }

  return DefSubclassProc(hWnd, uMsg, wParam, lParam);
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  
  // Registra o messenger para envio de eventos de stylus ao Dart
  g_messenger = flutter_controller_->engine()->messenger();

  HWND child_window = flutter_controller_->view()->GetNativeWindow();
  SetChildContent(child_window);

  // Subclass the Flutter child view window to intercept tablet gestures directly
  if (child_window) {
    SetWindowSubclass(child_window, FlutterChildSubclassProc, 1001, 0);
  }

  // Permanently disable touch/pen visual feedback circles, bubbles, and delays
  BOOL feedback_disabled = FALSE;
  HWND top_hwnd = GetHandle();
  if (top_hwnd) {
    for (int i = 1; i <= 11; i++) {
      SetWindowFeedbackSetting(top_hwnd, (FEEDBACK_TYPE)i, 0, sizeof(BOOL), &feedback_disabled);
    }
  }
  if (child_window) {
    for (int i = 1; i <= 11; i++) {
      SetWindowFeedbackSetting(child_window, (FEEDBACK_TYPE)i, 0, sizeof(BOOL), &feedback_disabled);
    }
  }

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Intercept WM_TABLET_QUERYSYSTEMGESTURESTATUS BEFORE Flutter's top-level window proc
  // to disable press-and-hold delays, flick gestures, barrel, and tap feedback animations.
  if (message == WM_TABLET_QUERYSYSTEMGESTURESTATUS) {
    return TABLET_FLAGS_ALL_DISABLED;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    // NATIVAMENTE IMPEDINDO O REDIMENSIONAMENTO ABAIXO DE 800x550 NO WINDOWS (Win32 API)
    case WM_GETMINMAXINFO: {
      MINMAXINFO* mmi = reinterpret_cast<MINMAXINFO*>(lparam);
      mmi->ptMinTrackSize.x = 800; // Largura mínima física em pixels
      mmi->ptMinTrackSize.y = 550; // Altura mínima física em pixels
      return 0;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
