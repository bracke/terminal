with Terminal.App.Cleanup_Diagnostics;

generic
   type First_Handle_Type is private;
   Null_First : First_Handle_Type;
   First_Operation : String;
   with procedure Destroy_First (Handle : First_Handle_Type);
   type Second_Handle_Type is private;
   Null_Second : Second_Handle_Type;
   Second_Operation : String;
   with procedure Destroy_Second (Handle : Second_Handle_Type);
   Failure_Source : Terminal.App.Cleanup_Diagnostics.Component :=
     Terminal.App.Cleanup_Diagnostics.Vulkan_Device;
procedure Terminal.App.Vulkan_Destroy_Pair
  (First   : in out First_Handle_Type;
   Second  : in out Second_Handle_Type;
   Success : out Boolean);

--  Destroy an ownership chain in dependency order.  If an earlier destructor
--  raises, later handles are quarantined rather than passed to Vulkan with an
--  indeterminate live dependency.
