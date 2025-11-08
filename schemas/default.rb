# Default Schema - Document & Folder Management
AuthSchema.schema :default, purpose: "Document and folder management with hierarchical permissions" do
  # User type - basic entity with no relations
  type :user

  # Group type - supports membership
  type :group do
    relation :member, allow: [:user, :group]
  end

  # Folder type - hierarchical container
  type :folder do
    relation :parent, allow: [:folder]
    relation :owner, allow: [:user, :group, "parent->owner"]

    # Relations with inheritance
    relation :editor, allow: [:owner, "parent->editor"]
    relation :viewer, allow: [:editor, "parent->viewer"]

    # Computed permissions using custom logic
    permission :can_delete do |context|
      # Only owners can delete folders
      context.check(context.actor, context.actor_id, :owner, context.subject, context.subject_id)
    end

    permission :can_move do |context|
      # Owners or parent owners can move
      is_owner = context.check(context.actor, context.actor_id, :owner, context.subject, context.subject_id)
      if is_owner
        true
      else
        # Check if user owns parent folder
        parents = context.repo.parents_of(subject: context.subject, id: context.subject_id)
        parents.any? do |parent|
          context.check(context.actor, context.actor_id, :owner, parent["subject"], parent["id"])
        end
      end
    end

    permission :can_share do |context|
      # Editors and above can share
      context.check(context.actor, context.actor_id, :editor, context.subject, context.subject_id)
    end
  end

  # Document type - inherits from parent folder
  type :doc do
    relation :parent, allow: [:folder]
    relation :owner, allow: [:user, :group]

    # Relations with parent inheritance
    relation :editor, allow: [:owner, "parent->editor"]
    relation :viewer, allow: [:editor, "parent->viewer"]

    # Computed permissions
    permission :can_delete do |context|
      # Only the document owner can delete (not parent owners)
      context.check(context.actor, context.actor_id, :owner, context.subject, context.subject_id)
    end

    permission :can_edit do |context|
      # Editors and above can edit
      context.check(context.actor, context.actor_id, :editor, context.subject, context.subject_id)
    end

    permission :can_archive do |context|
      # Document owner OR folder owner can archive
      is_doc_owner = context.check(context.actor, context.actor_id, :owner, context.subject, context.subject_id)
      if is_doc_owner
        true
      else
        # Check if user owns parent folder
        parents = context.repo.parents_of(subject: context.subject, id: context.subject_id)
        parents.any? do |parent|
          context.check(context.actor, context.actor_id, :owner, parent["subject"], parent["id"])
        end
      end
    end

    permission :can_view do |context|
      # Use relation-based viewer permission
      context.check(context.actor, context.actor_id, :viewer, context.subject, context.subject_id)
    end
  end

  # Document (aliased as 'document' for data generation)
  type :document do
    relation :parent, allow: [:folder]
    relation :owner, allow: [:user, :group]
    relation :editor, allow: [:owner, "parent->editor"]
    relation :viewer, allow: [:editor, "parent->viewer"]
  end

  # Comment - generic comment entity
  type :comment do
    relation :owner, allow: [:user, :group]
    relation :editor, allow: [:owner]
    relation :viewer, allow: [:editor]
  end

  # Wiki Page
  type :wiki_page do
    relation :owner, allow: [:user, :group]
    relation :editor, allow: [:owner]
    relation :viewer, allow: [:editor]
  end
end
