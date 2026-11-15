with Ada.Exceptions;

--  Runs a foreign unmap at most once.  The ownership marker is cleared before
--  crossing the foreign boundary so an exception cannot trigger a retry.
private package Terminal.App.Vulkan_Unmap_Once is
   procedure Run
     (Active  : in out Boolean;
      Unmap   : not null access procedure;
      Failed  : not null access procedure
        (Error : Ada.Exceptions.Exception_Occurrence);
      Success : out Boolean);
end Terminal.App.Vulkan_Unmap_Once;
