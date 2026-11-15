private package Terminal.App.Image_Store.Indexes is
   procedure Install
     (Container : in out Store;
      Object    : Image_Object_Access;
      Control   : access Allocation_Control := null);

   procedure Remove
     (Container : in out Store;
      Object    : not null Image_Object_Access);

   procedure Validate_Remove
     (Container : Store;
      Object    : not null Image_Object_Access);
end Terminal.App.Image_Store.Indexes;
