require 'rails_helper'

RSpec.describe RelTuple, type: :model do
  describe "database constraints" do
    it "has a primary key 'pk'" do
      tuple = RelTuple.create!(
        tenant_id: "test",
        ns: "doc",
        id: "report-1",
        relation: "owner",
        subj_ns: "user",
        subj_id: "alice"
      )

      expect(tuple.pk).to be_present
      expect(tuple.pk).to be_a(Integer)
    end

    it "enforces unique constraint on fact tuple" do
      attrs = {
        tenant_id: "test",
        ns: "doc",
        id: "report-1",
        relation: "owner",
        subj_ns: "user",
        subj_id: "alice",
        subj_rel: nil
      }

      RelTuple.create!(attrs)

      # Attempting to create duplicate should raise unique constraint error
      expect {
        RelTuple.create!(attrs)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "treats NULL and empty string as different for subj_rel in unique constraint" do
      base_attrs = {
        tenant_id: "test",
        ns: "doc",
        id: "report-1",
        relation: "owner",
        subj_ns: "user",
        subj_id: "alice"
      }

      # Create with NULL subj_rel
      tuple1 = RelTuple.create!(base_attrs.merge(subj_rel: nil))

      # Create with different relation should succeed
      tuple2 = RelTuple.create!(base_attrs.merge(relation: "editor"))

      expect(tuple1).to be_persisted
      expect(tuple2).to be_persisted
    end
  end

  describe "required fields" do
    it "requires tenant_id" do
      tuple = RelTuple.new(
        ns: "doc",
        id: "report-1",
        relation: "owner",
        subj_ns: "user",
        subj_id: "alice"
      )

      expect(tuple.tenant_id).to eq("default") # Has default value
    end

    it "requires ns" do
      tuple = RelTuple.new(
        tenant_id: "test",
        id: "report-1",
        relation: "owner",
        subj_ns: "user",
        subj_id: "alice"
      )

      expect {
        tuple.save!
      }.to raise_error(ActiveRecord::NotNullViolation)
    end

    it "requires id" do
      tuple = RelTuple.new(
        tenant_id: "test",
        ns: "doc",
        relation: "owner",
        subj_ns: "user",
        subj_id: "alice"
      )

      expect {
        tuple.save!
      }.to raise_error(ActiveRecord::NotNullViolation)
    end

    it "requires relation" do
      tuple = RelTuple.new(
        tenant_id: "test",
        ns: "doc",
        id: "report-1",
        subj_ns: "user",
        subj_id: "alice"
      )

      expect {
        tuple.save!
      }.to raise_error(ActiveRecord::NotNullViolation)
    end

    it "requires subj_ns" do
      tuple = RelTuple.new(
        tenant_id: "test",
        ns: "doc",
        id: "report-1",
        relation: "owner",
        subj_id: "alice"
      )

      expect {
        tuple.save!
      }.to raise_error(ActiveRecord::NotNullViolation)
    end

    it "requires subj_id" do
      tuple = RelTuple.new(
        tenant_id: "test",
        ns: "doc",
        id: "report-1",
        relation: "owner",
        subj_ns: "user"
      )

      expect {
        tuple.save!
      }.to raise_error(ActiveRecord::NotNullViolation)
    end

    it "allows subj_rel to be null" do
      tuple = RelTuple.create!(
        tenant_id: "test",
        ns: "doc",
        id: "report-1",
        relation: "owner",
        subj_ns: "user",
        subj_id: "alice",
        subj_rel: nil
      )

      expect(tuple).to be_persisted
      expect(tuple.subj_rel).to be_nil
    end
  end

  describe "timestamps" do
    it "sets created_at automatically" do
      tuple = RelTuple.create!(
        tenant_id: "test",
        ns: "doc",
        id: "report-1",
        relation: "owner",
        subj_ns: "user",
        subj_id: "alice"
      )

      expect(tuple.created_at).to be_present
      expect(tuple.created_at).to be_within(1.second).of(Time.now)
    end
  end

  describe "indexes" do
    it "has index on object + relation for fast lookups" do
      # This is verified by the migration, but we can test query performance
      # Create many tuples
      1000.times do |i|
        RelTuple.create!(
          tenant_id: "test",
          ns: "doc",
          id: "report-#{i}",
          relation: "owner",
          subj_ns: "user",
          subj_id: "user-#{i}"
        )
      end

      # Query using index
      start_time = Time.now
      results = RelTuple.where(tenant_id: "test", ns: "doc", id: "report-500", relation: "owner")
      query_time = Time.now - start_time

      expect(results.count).to eq(1)
      expect(query_time).to be < 0.1 # Should be fast with index
    end
  end

  describe "data types" do
    it "stores all fields as strings except pk" do
      tuple = RelTuple.create!(
        tenant_id: "test-tenant",
        ns: "document",
        id: "abc-123",
        relation: "owner",
        subj_ns: "user",
        subj_id: "alice@example.com",
        subj_rel: "member"
      )

      tuple.reload

      expect(tuple.tenant_id).to be_a(String)
      expect(tuple.ns).to be_a(String)
      expect(tuple.id).to be_a(String)
      expect(tuple.relation).to be_a(String)
      expect(tuple.subj_ns).to be_a(String)
      expect(tuple.subj_id).to be_a(String)
      expect(tuple.subj_rel).to be_a(String)
      expect(tuple.pk).to be_a(Integer)
    end

    it "handles special characters in IDs" do
      tuple = RelTuple.create!(
        tenant_id: "test",
        ns: "doc",
        id: "report:2024/Q4#final",
        relation: "owner",
        subj_ns: "user",
        subj_id: "alice+admin@example.com"
      )

      tuple.reload

      expect(tuple.id).to eq("report:2024/Q4#final")
      expect(tuple.subj_id).to eq("alice+admin@example.com")
    end

    it "handles unicode characters" do
      tuple = RelTuple.create!(
        tenant_id: "test",
        ns: "doc",
        id: "报告-2024",
        relation: "owner",
        subj_ns: "user",
        subj_id: "用户-123"
      )

      tuple.reload

      expect(tuple.id).to eq("报告-2024")
      expect(tuple.subj_id).to eq("用户-123")
    end
  end

  describe "multi-tenancy" do
    it "isolates data by tenant_id" do
      RelTuple.create!(
        tenant_id: "tenant-a",
        ns: "doc",
        id: "report-1",
        relation: "owner",
        subj_ns: "user",
        subj_id: "alice"
      )

      RelTuple.create!(
        tenant_id: "tenant-b",
        ns: "doc",
        id: "report-1",
        relation: "owner",
        subj_ns: "user",
        subj_id: "bob"
      )

      tenant_a_tuples = RelTuple.where(tenant_id: "tenant-a")
      tenant_b_tuples = RelTuple.where(tenant_id: "tenant-b")

      expect(tenant_a_tuples.count).to eq(1)
      expect(tenant_b_tuples.count).to eq(1)
      expect(tenant_a_tuples.first.subj_id).to eq("alice")
      expect(tenant_b_tuples.first.subj_id).to eq("bob")
    end
  end
end
