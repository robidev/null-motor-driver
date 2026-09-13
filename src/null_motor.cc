// null_motor: a Player driver plugin that provides one or more "motor"
// interfaces and silently discards every command sent to them.
//
// Intended use: swap this in as the *provider* of "motor:N" addresses that
// some other driver's "requires" list already depends on (by re-indexing
// the real provider elsewhere), so the dependent driver's requires binding
// stays intact and it never notices anything changed -- it just never
// gets a physical response to any motor command it sends.
//
// This driver never talks to real hardware and has no "requires" of its
// own: Setup()/Shutdown() are no-ops, and ProcessMessage() acks/consumes
// every PLAYER_MSGTYPE_CMD without forwarding it anywhere.
#include <cstdio>
#include <libplayercore/playercore.h>

class NullMotor : public Driver
{
public:
    NullMotor(ConfigFile *cf, int section);
    virtual ~NullMotor() {}

    virtual int Setup();
    virtual int Shutdown();
    virtual int ProcessMessage(QueuePointer &resp_queue,
                                player_msghdr *hdr,
                                void *data);

private:
    bool verbose;
    int num_interfaces;
};

NullMotor::NullMotor(ConfigFile *cf, int section)
    : Driver(cf, section, false, PLAYER_MSGQUEUE_DEFAULT_MAXLEN),
      verbose(false),
      num_interfaces(0)
{
    this->verbose = (cf->ReadInt(section, "verbose", 0) != 0);

    // Bind to every entry listed in this driver's own "provides" field.
    // "motor" is a vendor-added interface (not part of upstream Player, so
    // there's no PLAYER_MOTOR_CODE constant to compile against) -- code 0
    // means "match any interface type" to ReadDeviceAddr, which is fine
    // here since this driver's cfg block is only ever given motor:N
    // entries. Each entry is read independently by its position in this
    // block's provides array (index 0, 1, 2, ...) -- the resulting
    // interface/index actually bound comes from what each string itself
    // says (e.g. "motor:2" binds index 2), resolved at runtime by the
    // real libplayerinterface.so already on the robot (which knows about
    // the vendor's "motor" interface; this build doesn't need to), not
    // from the loop position -- so the entries may be listed in any order.
    for (int i = 0;; i++)
    {
        player_devaddr_t addr;
        if (cf->ReadDeviceAddr(&addr, section, "provides",
                                0, i, NULL) != 0)
        {
            break; // no more entries at this position
        }
        if (this->AddInterface(addr) != 0)
        {
            this->SetError(-1);
            return;
        }
        this->num_interfaces++;
    }

    if (this->num_interfaces == 0)
    {
        PLAYER_ERROR("null_motor: no \"motor:N\" entries found in provides[]");
        this->SetError(-1);
        return;
    }

    PLAYER_MSG1(1, "null_motor: providing %d motor interface(s); "
                   "every command sent to them will be silently discarded",
                this->num_interfaces);
}

int
NullMotor::Setup()
{
    return 0;
}

int
NullMotor::Shutdown()
{
    return 0;
}

int
NullMotor::ProcessMessage(QueuePointer & /*resp_queue*/,
                           player_msghdr *hdr,
                           void * /*data*/)
{
    if (hdr->type == PLAYER_MSGTYPE_CMD)
    {
        if (this->verbose)
        {
            PLAYER_MSG3(1, "null_motor: discarded cmd (subtype %d) for "
                           "interface %d:%d",
                        hdr->subtype, hdr->addr.interf, hdr->addr.index);
        }
        return 0; // consumed: no forwarding, no real actuation
    }
    // Anything else (requests, etc.) is not handled here; Player will
    // auto-NACK it on our behalf.
    return -1;
}

// --- Plugin registration -----------------------------------------------

Driver *
NullMotor_Init(ConfigFile *cf, int section)
{
    return static_cast<Driver *>(new NullMotor(cf, section));
}

void
null_motor_Register(DriverTable *table)
{
    table->AddDriver("null_motor", NullMotor_Init);
}

extern "C"
{
    int player_driver_init(DriverTable *table)
    {
        null_motor_Register(table);
        return 0;
    }
}
