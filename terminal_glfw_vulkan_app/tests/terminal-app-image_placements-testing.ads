package Terminal.App.Image_Placements.Testing is
   function Removal_Preflight_Is_Atomic return Boolean;

   procedure Remove_Conventional_Key
     (Container : in out Store;
      Placement : not null Conventional_Placement_Access);
   procedure Restore_Conventional_Key
     (Container : in out Store;
      Placement : not null Conventional_Placement_Access);
end Terminal.App.Image_Placements.Testing;
