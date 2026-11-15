with Ada.Exceptions;

generic
   type Handle_Type is private;
   Null_Handle : Handle_Type;
   with procedure Destroy (Handle : Handle_Type);
   with procedure Report_Failure
     (Occurrence : Ada.Exceptions.Exception_Occurrence);
procedure Terminal.App.Vulkan_Destroy_Once
  (Handle  : in out Handle_Type;
   Success : out Boolean);

--  Clear the caller's ownership marker before entering a foreign destructor.
--  If the foreign call raises after consuming the handle, report it and return
--  normally so copy-in/copy-out scalar handles are reliably cleared too.
