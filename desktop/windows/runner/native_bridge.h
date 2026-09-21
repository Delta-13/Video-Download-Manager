#pragma once
#include <flutter/binary_messenger.h>
void RegisterNativeBridge(flutter::BinaryMessenger* messenger);
void CloseNativeBridge();
