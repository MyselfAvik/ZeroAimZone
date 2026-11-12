#include "meta_sdk_module.h"
#include "core/version.h"
#if VERSION_MAJOR == 4
#include "core/config/engine.h"
#else
#include "core/engine.h"
#endif
#include "meta_sdk.h"

MetaSdk *meta_sdk;
void register_meta_sdk_plugin() {
	meta_sdk = memnew(MetaSdk);
	Engine::get_singleton()->add_singleton(Engine::Singleton("MetaSdk", meta_sdk));
}

void unregister_meta_sdk_plugin() {
	if (meta_sdk) {
		memdelete(meta_sdk);
	}
}
