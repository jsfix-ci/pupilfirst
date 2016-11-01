require 'rails_helper'

feature 'Faculty Weekly Slots' do
  let!(:faculty) { create :faculty, current_commitment: '20 mins per week for the first 6 months this year' }

  context 'User hits weekly slots page url' do
    scenario 'User uses a random token identifier' do
      visit weekly_slots_faculty_index_path(SecureRandom.base58(24))

      expect(page).to have_text("The page you were looking for doesn't exist.")
      expect(page).to have_text('You may have mistyped the address, or the page may have moved.')
    end

    scenario 'User uses the token of a faculty without email' do
      faculty.update(email: nil)
      visit weekly_slots_faculty_index_path(faculty.token)

      expect(page).to have_text("The page you were looking for doesn't exist.")
      expect(page).to have_text('You may have mistyped the address, or the page may have moved.')
    end

    scenario 'User uses the correct token of a valid faculty with no connection slots' do
      visit weekly_slots_faculty_index_path(faculty.token)
      expect(page).to have_text("Slots for #{faculty.name}")
      expect(page).to have_text("20 mins per week for the first 6 months this year")
    end
  end

  context 'User visits weekly_slot page of faculty with connection slots', js: true do
    let!(:connection_slot_1) { create :connect_slot, faculty: faculty, slot_at: ConnectSlot.next_week_start + 7.hours }
    let!(:connection_slot_2) { create :connect_slot, faculty: faculty, slot_at: ConnectSlot.next_week_start + 32.hours }
    scenario 'User verifies present slots and commitment' do
      visit weekly_slots_faculty_index_path(faculty.token)
      expect(page).to have_text("Slots for #{faculty.name}")
      expect(page).to have_text("20 mins per week for the first 6 months this year")
      expect(page).to have_selector('.connect-slot.selected', count: 1)
      expect(page.find('.connect-slot.selected', match: :first)).to have_text('07:00')

      click_on 'Tue'
      expect(page.find('li.active')).to have_text('Tue')
      expect(page).to have_selector('.connect-slot.selected', count: 1)
      expect(page.find('.connect-slot.selected', match: :first)).to have_text('08:00')
    end

    scenario 'User removes a present slot' do
      visit weekly_slots_faculty_index_path(faculty.token)

      # Remove first slot on Monday 07:00
      first_slot = page.find('.connect-slot.selected', match: :first)
      expect(first_slot).to have_text('07:00')
      first_slot.click
      expect(first_slot[:class]).to_not include('selected')
      click_on 'Save'
      expect(page).to have_text("We have successfully recorded your availability for the upcoming week")
      faculty.reload
      expect(faculty.connect_slots.count).to eq(1)
    end

    scenario 'User add two new slots' do
      visit weekly_slots_faculty_index_path(faculty.token)

      # Add a third slot on Monday 11:30
      expect(page.find('.connect-slot[data-day="1"][data-time="11.5"]')[:class]).to_not include('selected')
      page.find('.connect-slot[data-day="1"][data-time="11.5"]').click
      expect(page.find('.connect-slot[data-day="1"][data-time="11.5"]')[:class]).to include('selected')

      # Add a fourth slot on Tuesday 22:00
      click_on 'Tue'
      expect(page.find('li.active')).to have_text('Tue')
      expect(page.find('.connect-slot[data-day="2"][data-time="22.0"]')[:class]).to_not include('selected')
      page.find('.connect-slot[data-day="2"][data-time="22.0"]').click
      expect(page.find('.connect-slot[data-day="2"][data-time="22.0"]')[:class]).to include('selected')
      click_on 'Save'

      expect(page).to have_text("We have successfully recorded your availability for the upcoming week")
      faculty.reload
      expect(faculty.connect_slots.count).to eq(4)
      expect(faculty.connect_slots.third.slot_at).to eq(ConnectSlot.next_week_start + 11.hours + 30.minutes)
      expect(faculty.connect_slots.fourth.slot_at).to eq(ConnectSlot.next_week_start + 46.hours)
    end
  end
end
