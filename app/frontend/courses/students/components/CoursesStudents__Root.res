%%raw(`import "./CoursesStudents__Root.css"`)

open CoursesStudents__Types

let str = React.string

let tr = I18n.t(~scope="components.CoursesStudents__Root")
let ts = I18n.t(~scope="shared")

type coachNoteFilter = [#WithCoachNotes | #WithoutCoachNotes | #IgnoreCoachNotes]

module Item = {
  type t = StudentInfo.t
}

module PagedStudents = Pagination.Make(Item)

type state = {
  loading: LoadingV2.t,
  students: PagedStudents.t,
  filterInput: string,
  totalEntriesCount: int,
  reloadDistributionAt: option<Js.Date.t>,
  studentDistribution: array<DistributionInLevel.t>,
}

type action =
  | UnsetSearchString
  | UpdateFilterInput(string)
  | LoadStudents(
      option<string>,
      bool,
      array<StudentInfo.t>,
      int,
      option<array<DistributionInLevel.t>>,
    )
  | BeginLoadingMore
  | BeginReloading

let reducer = (state, action) =>
  switch action {
  | UnsetSearchString => {
      ...state,
      filterInput: "",
    }
  | UpdateFilterInput(filterInput) => {...state, filterInput: filterInput}
  | LoadStudents(endCursor, hasNextPage, students, totalEntriesCount, studentDistribution) =>
    let updatedStudent = switch state.loading {
    | LoadingMore => Js.Array2.concat(PagedStudents.toArray(state.students), students)
    | Reloading(_) => students
    }

    {
      ...state,
      students: PagedStudents.make(updatedStudent, hasNextPage, endCursor),
      loading: LoadingV2.setNotLoading(state.loading),
      totalEntriesCount: totalEntriesCount,
      reloadDistributionAt: None,
      studentDistribution: Belt.Option.getWithDefault(studentDistribution, []),
    }
  | BeginLoadingMore => {...state, loading: LoadingMore}
  | BeginReloading => {
      ...state,
      loading: LoadingV2.setReloading(state.loading),
      reloadDistributionAt: Some(Js.Date.make()),
    }
  }

module UserDetailsFragment = UserDetails.Fragment
module LevelFragment = Shared__Level.Fragment
module CohortFragment = Cohort.Fragment
module UserProxyFragment = UserProxy.Fragment

module StudentsQuery = %graphql(`
    query StudentsFromCoursesStudentsRootQuery($courseId: ID!, $after: String, $filterString: String, $skipIfLoadingMore: Boolean!) {
      courseStudents(courseId: $courseId, filterString: $filterString, first: 20, after: $after, ) {
        nodes {
          id,
          taggings
          user {
            ...UserDetailsFragment
          }
          level {
            ...LevelFragment
          }
          cohort {
            ...CohortFragment
          }
          personalCoaches {
            ...UserProxyFragment
          }
          accessEndsAt
          droppedOutAt
        }
        pageInfo{
          endCursor,hasNextPage
        }
        totalCount
      }
      studentDistribution(courseId: $courseId, filterString: $filterString) @skip(if: $skipIfLoadingMore) {
        id
        number
        filterName
        studentsInLevel
        unlocked
      }
    }
  `)

let getStudents = (send, courseId, cursor, ~loadingMore=false, params) => {
  let filterString = Webapi.Url.URLSearchParams.toString(params)

  StudentsQuery.makeVariables(
    ~courseId,
    ~after=?cursor,
    ~filterString=?Some(filterString),
    ~skipIfLoadingMore={loadingMore},
    (),
  )
  |> StudentsQuery.fetch
  |> Js.Promise.then_((response: StudentsQuery.t) => {
    let nodes = response.courseStudents.nodes
    let students =
      nodes->Js.Array2.map(s =>
        StudentInfo.make(
          ~id=s.id,
          ~taggings=s.taggings,
          ~user=UserDetails.makeFromFragment(s.user),
          ~level=Shared__Level.makeFromFragment(s.level),
          ~cohort=Cohort.makeFromFragment(s.cohort),
          ~accessEndsAt=s.accessEndsAt->Belt.Option.map(DateFns.decodeISO),
          ~droppedOutAt=s.droppedOutAt->Belt.Option.map(DateFns.decodeISO),
          ~personalCoaches=s.personalCoaches->Js.Array2.map(UserProxy.makeFromFragment),
        )
      )

    let studentDistribution =
      response.studentDistribution->Belt.Option.map(p =>
        p->Js.Array2.map(d =>
          DistributionInLevel.make(
            ~id=d.id,
            ~number=d.number,
            ~studentsInLevel=d.studentsInLevel,
            ~unlocked=d.unlocked,
            ~filterName=d.filterName,
          )
        )
      )
    send(
      LoadStudents(
        response.courseStudents.pageInfo.endCursor,
        response.courseStudents.pageInfo.hasNextPage,
        students,
        response.courseStudents.totalCount,
        studentDistribution,
      ),
    )
    Js.Promise.resolve()
  })
  |> ignore
}

let applicableLevels = levels => levels |> Js.Array.filter(level => Level.number(level) != 0)

let makeFilters = () => {
  [
    CourseResourcesFilter.makeFilter("cohort", "Cohort", DataLoad(#Cohort), "green"),
    CourseResourcesFilter.makeFilter("include", "Include", Custom("Inactive Students"), "orange"),
    CourseResourcesFilter.makeFilter("level", "Level", DataLoad(#Level), "yellow"),
    CourseResourcesFilter.makeFilter(
      "student_tags",
      "Student Tags",
      DataLoad(#StudentTag),
      "focusColor",
    ),
    CourseResourcesFilter.makeFilter("user_tags", "User Tags", DataLoad(#UserTag), "blue"),
    CourseResourcesFilter.makeFilter("email", "Search by Email", Search, "gray"),
    CourseResourcesFilter.makeFilter("name", "Search by Name", Search, "gray"),
  ]
}

let computeInitialState = () => {
  loading: LoadingV2.empty(),
  students: Unloaded,
  filterInput: "",
  totalEntriesCount: 0,
  reloadDistributionAt: None,
  studentDistribution: [],
}

let reloadStudents = (courseId, params, send) => {
  send(BeginReloading)
  getStudents(send, courseId, None, params)
}

let onSelect = (key, value, params) => {
  Webapi.Url.URLSearchParams.set(key, value, params)
  RescriptReactRouter.push("?" ++ Webapi.Url.URLSearchParams.toString(params))
}

let selectLevel = (levels, params, levelId) => {
  let level =
    levels |> ArrayUtils.unsafeFind(level => Level.id(level) == levelId, tr("not_found") ++ levelId)

  onSelect("level", level->Level.name, params)
}

let showStudents = (state, students) => {
  <div>
    <CoursesStudents__StudentsList students />
    {PagedStudents.showStats(state.totalEntriesCount, Array.length(students), "Students")}
  </div>
}

@react.component
let make = (~courseId) => {
  let (state, send) = React.useReducer(reducer, computeInitialState())

  let url = RescriptReactRouter.useUrl()
  let params = Webapi.Url.URLSearchParams.make(url.search)

  React.useEffect1(() => {
    reloadStudents(courseId, params, send)
    None
  }, [courseId, url.search])

  <div role="main" ariaLabel="Students" className="flex-1 flex flex-col overflow-y-auto">
    <div className="w-full md:w-4/5 px-4 mt-8 md:mt-25 mx-auto">
      <div className="bg-gray-50 w-full">
        <h1 className="text-2xl font-semibold"> {"Students"->str} </h1>
        <div className="p-5 bg-gray-100 rounded-lg mt-6">
          <p className="text-gray-600 text-sm font-medium">
            {"Level Wise distribution of students"->str}
          </p>
          <CoursesStudents__StudentDistribution
            params={params} studentDistribution={state.studentDistribution}
          />
        </div>
        <div
          className="p-5 mt-6 bg-white rounded-md border border-gray-300 relative md:sticky md:top-16 z-10">
          <p className="uppercase pb-2 text-xs font-semibold"> {"Filter students by"->str} </p>
          <CourseResourcesFilter
            courseId
            filters={makeFilters()}
            search={url.search}
            sorter={CourseResourcesFilter.makeSorter(
              "sort_by",
              ["Name", "First Created", "Last Created"],
              "Name",
            )}
          />
        </div>
        <div className="my-6">
          {switch state.students {
          | Unloaded => SkeletonLoading.multiple(~count=10, ~element=SkeletonLoading.userCard())
          | PartiallyLoaded(students, cursor) =>
            <div>
              {showStudents(state, students)}
              {switch state.loading {
              | LoadingMore => SkeletonLoading.multiple(~count=3, ~element=SkeletonLoading.card())
              | Reloading(times) =>
                ReactUtils.nullUnless(
                  <button
                    className="btn btn-primary-ghost cursor-pointer w-full mt-4"
                    onClick={_ => {
                      send(BeginLoadingMore)
                      getStudents(send, courseId, Some(cursor), params, ~loadingMore=true)
                    }}>
                    {ts("load_more")->str}
                  </button>,
                  ArrayUtils.isEmpty(times),
                )
              }}
            </div>
          | FullyLoaded(students) => showStudents(state, students)
          }}
        </div>
      </div>
      {PagedStudents.showLoading(state.students, state.loading)}
    </div>
  </div>
}
