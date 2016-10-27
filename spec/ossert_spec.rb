# frozen_string_literal: true
require 'spec_helper'

describe Ossert do
  describe 'common behaviour' do
    let(:projectA) { Ossert::Project.load_by_name(@a_project) }
    let(:projectB) { Ossert::Project.load_by_name(@b_project) }
    let(:projectC) { Ossert::Project.load_by_name(@c_project) }
    let(:projectD) { Ossert::Project.load_by_name(@d_project) }
    let(:projectE) { Ossert::Project.load_by_name(@e_project) }

    let(:project_A_time_range) do
      [Date.parse('01/04/2010'), Date.parse('01/10/2016')]
    end

    it { expect(Ossert::Project.load_by_name('Not Exists')).to be_nil }
    it do
      expect(projectA.prepare_time_bounds!).to eq(project_A_time_range)
    end

    context 'when classifiers are ready' do
      before { Ossert::Classifiers.train }

      let(:grades_A) do
        { popularity: 'A', maintenance: 'A', maturity: 'A' }
      end
      let(:grades_B) do
        { popularity: 'A', maintenance: 'B', maturity: 'A' }
      end
      let(:grades_C) do
        { popularity: 'C', maintenance: 'C', maturity: 'C' }
      end
      let(:grades_D) do
        { popularity: 'D', maintenance: 'A', maturity: 'D' }
      end
      let(:grades_E) do
        { popularity: 'E', maintenance: 'E', maturity: 'E' }
      end

      it do
        expect(projectA.grade_by_classifier).to eq(grades_A)
        expect(projectB.grade_by_classifier).to eq(grades_B)
        expect(projectC.grade_by_classifier).to eq(grades_C)
        expect(projectD.grade_by_classifier).to eq(grades_D)
        expect(projectE.grade_by_classifier).to eq(grades_E)
      end

      it { expect(projectA.agility.quarters.last_year_as_hash).to be_a_kind_of(Hash) }
      it { expect(projectA.agility.quarters.last_year_as_hash(3)).to be_a_kind_of(Hash) }
      it { expect(projectA.agility.quarters.last_year_as_hash(5)).to be_a_kind_of(Hash) }
      it { expect(projectA.agility.quarters.last_year_data).to be_a_kind_of(Array) }
      it { expect(projectA.agility.quarters.last_year_data(3)).to be_a_kind_of(Array) }
      it { expect(projectA.agility.quarters.last_year_data(5)).to be_a_kind_of(Array) }

      context 'when project is decorated' do
        let(:project) { projectE.decorated }
        let(:call_references) do
          project.preview_reference_values_for(metric_name, section)
        end

        describe '#reference_values_per_grade' do
          context 'when agility_total metric given' do
            let(:section) { :agility_total }

            context 'when growing metric given' do
              let(:metric_name) { 'issues_all_count' }

              it do
                expect(call_references).to eq('A' => '> 92',
                                              'B' => '> 68',
                                              'C' => '> 19',
                                              'D' => '> 10',
                                              'E' => '> 2')
              end
            end

            context 'when lowering metric given' do
              let(:metric_name) { 'stale_branches_count' }

              it do
                expect(call_references).to eq('A' => '< 3',
                                              'B' => '< 6',
                                              'C' => '< 9',
                                              'D' => '< 12',
                                              'E' => '< 15')
              end
            end
          end
        end
      end
    end

    context 'when classifiers are not ready' do
      before { Ossert::Classifiers::Growing.all = nil }

      it do
        expect { projectA.grade_by_classifier }.to(
          raise_error(StandardError)
        )
      end
    end
  end

  describe 'QuartersStore' do
    describe '.build_quarters_intervals' do
      context 'with valid period' do
        let(:period) do
          { from: Time.parse('2013-09-01'), to: Time.parse('2015-09-01') }
        end
        let(:quarters) do
          [
            ['2013-07-01', '2013-09-30'],
            ['2013-10-01', '2013-12-31'],
            ['2014-01-01', '2014-03-31'],
            ['2014-04-01', '2014-06-30'],
            ['2014-07-01', '2014-09-30'],
            ['2014-10-01', '2014-12-31'],
            ['2015-01-01', '2015-03-31'],
            ['2015-04-01', '2015-06-30'],
            ['2015-07-01', '2015-09-30']
          ].map do |(start, finish)|
            [Time.parse(start).to_i, Time.parse(finish).end_of_day.to_i]
          end
        end
        it do
          expect(Ossert::QuartersStore.build_quarters_intervals(period)).to eq(quarters)
        end
      end
      context 'with invalid period' do
        let(:period){ { from: 1.year.ago, to: 3.years.ago } }
        it do
          expect(Ossert::QuartersStore.build_quarters_intervals(period)).to eq([])
        end
      end
    end
  end
end
