package body Terminal.App.Vulkan_Unmap_Once is
   procedure Run
     (Active  : in out Boolean;
      Unmap   : not null access procedure;
      Failed  : not null access procedure
        (Error : Ada.Exceptions.Exception_Occurrence);
      Success : out Boolean) is
   begin
      Success := True;
      if not Active then
         return;
      end if;
      Active := False;
      begin
         Unmap.all;
      exception
         when Error : others =>
            Success := False;
            Failed.all (Error);
      end;
   end Run;
end Terminal.App.Vulkan_Unmap_Once;
