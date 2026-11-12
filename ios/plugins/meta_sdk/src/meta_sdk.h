#ifndef METASDK_H
#define METASDK_H

#include "core/version.h"
#if VERSION_MAJOR == 4
#include "core/object/class_db.h"
#else
#include "core/object.h"
#endif

class MetaSdk : public Object {

	GDCLASS(MetaSdk, Object);

	static MetaSdk *instance;
	static void _bind_methods();
	String current_user_id;

public:
	static MetaSdk *get_singleton();
    void initialize(String app_id, String client_token);
    void logEvent(String event_name, Dictionary params);
    void setUserId(String user_id);
    String getMetaIdentity();
    void setDebugEnabled(bool enabled);
    void handleFirstLaunch(String first_event, String second_event);
    bool isReady();
	MetaSdk();
	~MetaSdk();
};

#endif
